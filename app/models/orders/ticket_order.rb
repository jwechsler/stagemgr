class TicketOrder < Order

  has_many :ticket_line_items, :foreign_key=>:order_id
  accepts_nested_attributes_for :ticket_line_items, :allow_destroy=>true

  validates_associated :ticket_line_items
  before_validation :set_tickets_for_pass_redemption

  validates_each :status do |record, attr, value|

    if value == PROCESSED
      unless record.ticket_line_items.empty? || record.ticket_quantity > 0
        record.errors.add :ticket_line_items, "must contain at least one ticket."
      end
    end
  end

  def self.reassign_payments(offer)
    orders = Order.where("id in (select order_id from payments where flex_pass_id in (select id from flex_passes where flex_pass_offer_id = :offer_id))",
                         {:offer_id => offer.id})

    orders.each { |o|
      was = o.to_s
      o.set_ticket_classes_using_offer(offer)
      o.save!
      if was != o.to_s
        puts "Order #{o.id}: #{was} converted to #{o.to_s}"
      else
        puts "Order #{o.id}: #{was}"
      end
    }

    nil

  end

  def exchangeable?
    self.status == Order::PROCESSED || self.status == Order::FULFILLED || self.status == Order::UNCLAIMED
  end

  def display_code
    self.performance.try(:performance_code)
  end


  def ticket_quantity
    self.ticket_line_items(false).uniq.to_a.sum { |li| li.respond_to?(:ticket_count) ? li.ticket_count : 0 }
  end

  def performance_code=(string)
    self.performance=Performance.find_by_performance_code(string)
  end

  def number_of_tickets_of_all_payments
    self.payments.to_a.sum { |fpp| fpp.number_of_tickets }
  end

  def attended?
    [PROCESSED, FULFILLED].include?(self.status)
  end

  def ticket_quantity_by_class(class_code)
    self.ticket_line_items.to_a.sum { |li| li.ticket_class.class_code == class_code ? li.ticket_count : 0 }

  end


  def contains_tickets?
    (self.line_items.select { |li| (li.is_a? TicketLineItem) && (li.ticket_count > 0) } + self.ticket_line_items.select { |li| li.ticket_count > 0 }).size > 0
  end

  private
  def set_ticket_classes_using_offer(offer)
    new_ticket_class = production_ticket_class_from_offer(offer)
    if !new_ticket_class.nil?
      self.ticket_line_items.each { |li|
        new_line_item = TicketLineItem.new
        new_line_item.ticket_class = new_ticket_class
        old_price = li.ticket_class.ticket_price
        new_line_item.ticket_count = li.ticket_count
        new_line_item.price_override = self.applicable_price(li.ticket_class, new_ticket_class) if new_ticket_class.ticket_type == TicketClass::DONATION
        self.ticket_line_items << new_line_item
        self.ticket_line_items.delete(li)

      }
    end
  end

  def set_tickets_for_pass_redemption
    if self.status_changed? && self.status == Order::PROCESSED
      if self.paid_with_pass?
        flex_pass = FlexPass.find_by_code(self.flex_pass_code)
        offer = flex_pass.flex_pass_offer
        set_ticket_classes_using_offer(offer)
      end
      if self.paid_with_membership?
        membership = Membership.find_by_member_code(self.member_code)
        offer = membership.membership_offer
        set_ticket_classes_using_offer(offer)
        self.ticket_line_items

      end

    end
  end

end