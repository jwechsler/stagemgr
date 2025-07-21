# Batch Printing System - Detailed Overview

## System Architecture

The batch printing system is a sophisticated queuing and processing mechanism designed to handle high-volume ticket printing efficiently and reliably. Here's how it works:

## 1. Core Components

### **PrintBatch Model**
- **Purpose**: Represents a collection of orders to be printed together
- **Key Fields**:
  - `batch_id`: Unique identifier (format: `batch_YYYYMMDD_HHMMSS_N`)
  - `status`: Lifecycle state (`pending` → `ready` → `processing` → `complete`)
  - `order_count`: Total orders in batch
  - `printed_count`: Successfully printed orders
  - `error_count`: Failed print attempts
  - `ready_at`, `started_at`, `completed_at`: Timestamps for tracking

### **PrintBatchProcessorJob** 
- **Purpose**: Background job that handles actual printing
- **Features**:
  - Singleton pattern (only one instance queued at a time)
  - Self-scheduling for continuous processing
  - Comprehensive error handling and logging
  - Sequential order processing with proper status tracking

## 2. Batch Lifecycle

### **Stage 1: Batch Creation (Pending)**
```ruby
# When orders arrive from stagemgr
batch = PrintBatch.create!(
  batch_id: "batch_20250717_143052_1",
  status: 'pending'
)
```

### **Stage 2: Batch Closure (Ready)**
```ruby
# POST /print_batches/:batch_id/close
batch.update!(
  status: 'ready',
  ready_at: Time.current,
  order_count: orders.count
)
PrintBatchProcessorJob.perform_later # Triggers processing
```

### **Stage 3: Processing**
```ruby
# Job marks batch as processing
batch.update!(
  status: 'processing',
  started_at: Time.current
)

# Prints each order sequentially
orders.each do |order|
  printer.print_order(order)
  order.mark_printed!
end
```

### **Stage 4: Completion**
```ruby
batch.update!(
  status: 'complete',
  completed_at: Time.current,
  printed_count: successful_prints,
  error_count: failed_prints
)
```

## 3. API Endpoints

### **Batch Management**
- `POST /print_batches` - Create new batch
- `GET /print_batches/:id` - Get batch status
- `POST /print_batches/:batch_id/close` - Close batch and start printing
- `GET /print_batches` - List all batches

### **Order Management**
- `POST /orders` - Create order and assign to batch
- `PUT /orders/:id` - Update order (triggers reprint if needed)
- `POST /orders/:id/print` - Force manual print

## 4. Batch Processing Logic

### **Order Selection Priority**
```ruby
# Processing batches take priority over ready batches
scope :printable, -> { 
  where(status: ['ready', 'processing'])
    .order("CASE WHEN status = 'processing' THEN 0 ELSE 1 END, created_at ASC")
}
```

### **Printing Sequence**
1. **Find Next Batch**: Gets first printable batch
2. **Mark Processing**: Updates status to prevent conflicts
3. **Print Orders**: Processes each order by `batch_sequence`
4. **Update Counts**: Tracks successes/failures
5. **Complete Batch**: Marks as complete
6. **Schedule Next**: Checks for more batches to process

## 5. Concurrency & Safety Features

### **Job Uniqueness (Singleton Pattern)**
```ruby
def self.perform_later(*args)
  existing_job = Delayed::Job.where(
    "handler LIKE ?", "%PrintBatchProcessorJob%"
  ).where("locked_at IS NULL").first
  
  return nil if existing_job # Skip duplicate
  
  super(*args) # Queue new job
end
```

### **Database-Level Safety**
- **Unique constraints** on batch_id
- **Status transitions** prevent race conditions
- **Atomic updates** ensure data consistency
- **Row-level locking** during batch selection

## 6. Startup Recovery System

### **Problem Solved**
When the tktprint service restarts, batches in `ready` or `processing` status could be orphaned indefinitely.

### **Solution**
```ruby
# config/initializers/batch_startup_recovery.rb
Rails.application.config.after_initialize do
  unless Rails.env.test?
    Thread.new do
      sleep 2 # Allow database connections to stabilize
      
      printable_batches = PrintBatch.printable
      if printable_batches.any?
        PrintBatchProcessorJob.perform_later
        Rails.logger.info("Batch processing job scheduled for startup recovery")
      end
    end
  end
end
```

## 7. Error Handling & Resilience

### **Printer Failures**
- Individual order failures don't stop batch processing
- Failed orders marked with specific error messages
- Batch continues with remaining orders
- Final counts reflect successes vs failures

### **System Failures**
- Database connection issues handled gracefully
- Job failures logged with full stack traces
- Batch state preserved for recovery
- Automatic retry through DelayedJob

### **Network Issues**
- Printer connectivity problems logged
- Orders marked as failed with retry possibility
- Batch processing continues when printer recovers

## 8. Integration Points

### **Stagemgr Integration**
- **Order Creation**: POST /orders with batch assignment
- **Batch Closure**: Triggered after order collection complete
- **Status Monitoring**: Real-time batch status updates

### **Printer Integration**
- **TCP Socket Communication**: Port 9100 standard
- **FGL Command Generation**: Thermal printer language
- **Logo/Barcode Support**: Embedded graphics printing
- **Receipt Generation**: Dual-format output

## 9. Monitoring & Observability

### **Logging**
```ruby
Rails.logger.info("Processing print batch: #{batch.batch_id}")
Rails.logger.info("Printing #{orders.count} orders in batch #{batch.batch_id}")
Rails.logger.info("Successfully printed order #{order.id}")
Rails.logger.error("Failed to print order #{order.id}")
```

### **Metrics Available**
- Batch processing times
- Success/failure rates per batch
- Order processing throughput
- Error categorization and trends

## 10. Configuration

### **DelayedJob Settings**
```ruby
Delayed::Worker.max_attempts = 1024
Delayed::Worker.max_run_time = 5.minutes
Delayed::Worker.sleep_delay = 3
```

### **Production Deployment**
- **Single Worker**: Ensures sequential processing
- **Background Processing**: Non-blocking web requests
- **Persistent Jobs**: Survives service restarts
- **Log Rotation**: Prevents disk space issues

## Key Benefits

1. **Reliability**: Batches never get lost, automatic recovery
2. **Efficiency**: Bulk processing reduces printer overhead
3. **Scalability**: Can handle high-volume ticket sales
4. **Monitoring**: Comprehensive logging and status tracking
5. **Fault Tolerance**: Individual failures don't crash the system
6. **Consistency**: Guaranteed sequential processing order

This system transforms individual ticket printing into a robust, enterprise-grade batch processing solution that can handle Theater Wit's ticketing demands reliably and efficiently.