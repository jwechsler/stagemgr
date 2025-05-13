We are working on a reported bug.  Currently, the box office has reported the following behavior:

* When you batch print tickets from the report screen, there is an 
initial batch of records that are printed in the correct order.  

* Then several minutes after the batch prints, a set of tickets 
comes out in no particular order.

* It is possible that this apparent asynchronous behavior is due to 
submission errors via json to the remote tktprint instance that are then resubmitted
via resque

Here is the submitted bug report:
After batch printing, when printing appears to be done, the ticket printer will start up again and continue printing up to 20 tickets or more for that evening's performance, not in alphabetical order. We've nicknamed this the tail... when it first started it was 2 or 3 orders, now it's many more.

## Implementation Strategy

To fix this issue, we will implement a new PrintBatch system that tracks batch printing attempts independently of TicketOrders. This ensures proper sequencing even when orders need to be retried.

### New Models

1. PrintBatch - Represents a batch printing session:
```ruby
class PrintBatch < ApplicationRecord
  has_many :print_batch_items
  has_many :ticket_orders, through: :print_batch_items
  
  validates :batch_id, presence: true, uniqueness: true
  
  before_validation :generate_batch_id, on: :create
  
  def generate_batch_id
    self.batch_id ||= SecureRandom.uuid
  end
  
  def incomplete_items
    print_batch_items.where(print_status: ['pending', 'failed'])
  end
  
  def complete?
    incomplete_items.empty?
  end
end
```

2. PrintBatchItem - Represents each order in a batch:
```ruby
class PrintBatchItem < ApplicationRecord
  belongs_to :print_batch
  belongs_to :ticket_order
  
  validates :sequence_number, presence: true
  validates :print_status, presence: true
  
  enum print_status: {
    pending: 0,
    sent: 1,
    failed: 2,
    completed: 3
  }
end
```

### Database Changes

Only need to create new tables, no modifications to existing schema:

```ruby
class CreatePrintBatches < ActiveRecord::Migration[6.1]
  def change
    create_table :print_batches do |t|
      t.string :batch_id, null: false
      t.integer :total_items, null: false
      t.timestamps
      
      t.index :batch_id, unique: true
    end
    
    create_table :print_batch_items do |t|
      t.references :print_batch, null: false, foreign_key: true
      t.references :ticket_order, null: false, foreign_key: true
      t.integer :sequence_number, null: false
      t.integer :print_status, null: false, default: 0
      t.string :error_message
      t.timestamps
      
      t.index [:print_batch_id, :sequence_number], unique: true
    end
  end
end
```

### Process Flow

1. When batch printing is initiated:
   - Create a new PrintBatch record
   - Create PrintBatchItems for each TicketOrder with sequence numbers
   - Send print requests with batch metadata
   - Track status of each print attempt

2. For each print request:
   - Include batch_id, sequence_number, and batch_total in PrintOrder
   - Update PrintBatchItem status based on success/failure
   - Store error messages if printing fails

3. For failed prints:
   - Original sequence information is preserved in PrintBatchItem
   - Retries can use the same batch_id and sequence_number
   - Tktprint can still order items correctly when retried

### Benefits

1. Non-invasive Changes:
   - No modifications needed to TicketOrder or PrintOrder schemas
   - Existing print functionality remains unchanged
   - Individual prints and reprints still work as before

2. Better Tracking:
   - Each batch print attempt is recorded
   - Failed prints are tracked with error messages
   - Can report on batch completion status

3. Improved Retry Handling:
   - Failed prints maintain their original sequence
   - Can retry specific items within a batch
   - Tktprint receives consistent ordering information

This implementation ensures that all tickets maintain their proper sequence, even when some need to be retried. The "tail" issue will be resolved because retry attempts will include the original batch and sequence information, allowing tktprint to maintain the correct order.

### Tktprint Implementation

The tktprint service will be enhanced to coordinate batch printing using Redis for temporary state management. This avoids schema changes while ensuring proper sequencing.

#### Model Changes

1. Update Order model with batch attributes:
```ruby
class Order < ActiveRecord::Base
  # Add batch attributes (non-persisted)
  attr_accessor :batch_id, :sequence_number, :batch_total
  
  # Add sorting scope for batches
  scope :in_batch_sequence, -> { order(:sequence_number) }
  
  # Add batch validation
  validates :sequence_number, :batch_total, numericality: true, if: :batch_id
  validates :batch_id, presence: true, if: :sequence_number
end
```

#### New Components

1. BatchManager service for coordination:
```ruby
class BatchManager
  def self.process_order(order)
    return order.print unless order.batch_id
    
    Rails.logger.info("Batch #{order.batch_id}: Processing item #{order.sequence_number} of #{order.batch_total}")
    
    # Store batch orders in Redis with expiration
    REDIS.multi do
      REDIS.sadd("batch:#{order.batch_id}", order.id)
      REDIS.expire("batch:#{order.batch_id}", 1.hour)
    end
    
    # Check if we have all orders for this batch
    batch_size = REDIS.scard("batch:#{order.batch_id}")
    
    if batch_size == order.batch_total
      Rails.logger.info("Batch #{order.batch_id}: All #{batch_size} orders received, processing in sequence")
      process_complete_batch(order.batch_id)
    else
      Rails.logger.info("Batch #{order.batch_id}: Waiting for more orders (#{batch_size}/#{order.batch_total})")
    end
  end
  
  private
  
  def self.process_complete_batch(batch_id)
    order_ids = REDIS.smembers("batch:#{batch_id}")
    orders = Order.where(id: order_ids).in_batch_sequence
    
    orders.each do |order|
      order.print
    end
    
    REDIS.del("batch:#{batch_id}")
  end
end
```

#### Modified Components

1. Update Order#print method:
```ruby
def print
  return true if self.status == Order::PRINTED
  
  Rails.logger.info("*** print called (#{self.status}) #{batch_id ? "- Batch #{batch_id}" : ""}")
  
  if batch_id
    BatchManager.process_order(self)
  else
    printer = Printer.new
    if printer.print_order(self)
      self.status = Order::PRINTED
      self.save
    else
      false
    end
  end
end
```

2. Enhance Printer#print_order for batch handling:
```ruby
def print_order(order)
  result = false
  unless @address.blank?
    TCPSocket.open(@address, @port) do |socket|
      @socket = socket
      
      # If this is part of a batch, log it
      if order.batch_id
        Rails.logger.info("Processing batch order #{order.batch_id} - #{order.sequence_number}/#{order.batch_total}")
      end
      
      # Print tickets in sequence
      order.tickets.each { |ticket| self.print_ticket(ticket) }
      self.print_receipt(order)
      self.flush(socket)
      
      # Add extra delay between batch items to ensure proper sequencing
      if order.batch_id
        sleep(2.5)  # Increased from 1.75 for batch printing
      else
        sleep(1.75) # Original delay for single orders
      end
    end
  end
end
```

### Batch Processing Flow

1. When an order with batch information arrives:
   - BatchManager stores the order ID in Redis under the batch key
   - Sets a 1-hour expiration to prevent stale data
   - Checks if all orders for the batch have arrived

2. When all batch orders are received:
   - Orders are retrieved and sorted by sequence_number
   - Each order is printed in sequence
   - Extra delay is added between prints
   - Batch data is cleaned up from Redis

3. For failed orders:
   - Original batch information is preserved
   - When retried, they rejoin their batch in Redis
   - Maintain their original sequence number
   - Print in proper order when batch is complete

### Benefits

1. No Schema Changes:
   - Uses attr_accessor for batch attributes
   - Redis for temporary state management
   - Maintains backward compatibility

2. Reliable Sequencing:
   - Orders wait for their complete batch
   - Prints maintain sequence even after failures
   - Extra delays prevent printer timing issues

3. Clean Implementation:
   - Separates batch logic into dedicated service
   - Uses Redis TTL to prevent stale data
   - Comprehensive logging for debugging

4. Failure Handling:
   - Failed orders maintain batch association
   - Can be retried without losing sequence
   - Batch expires if too many failures

This implementation ensures that all tickets in a batch are printed in the correct order, even when some need to be retried, eliminating the "tail" issue where some tickets print immediately while others are delayed.
