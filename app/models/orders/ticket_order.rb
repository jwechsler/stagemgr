class TicketOrder < Order


  has_many :ticket_line_items, :foreign_key=>:order_id
  accepts_nested_attributes_for :ticket_line_items, :allow_destroy=>true

  validates_associated :ticket_line_items
  validates_presence_of :performance
  before_validation :set_tickets_for_pass_redemption
  before_save :set_theater
  before_save :remove_empty_ticket_lines

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

  def refundable?
    self.exchangeable?
  end

  def display_code
    self.performance.try(:performance_code)
  end

  def description
    performance_s = self.performance.nil_or.to_short_s
    "#{performance_s} (#{self.ticket_detail_description})"
  end

  def to_s
    self.ticket_detail_description
  end

  def ticket_detail_description
    self.ticket_line_items.map { |li|
      if li.ticket_count > 0
        li.to_s
      else
        ""
      end
    }.join(', ')
  end

  def send_to_printer
    unless self.print_order_id.nil?
      print_order = PrintOrder.find(self.print_order_id)
      if print_order.status == 'Printed'
        print_order.status = 'Unprinted'
        print_order.reprints += 1
        print_order.save!
      end
    else
      credit_lines = self.performance.production.credit_lines.split("\n")
      credit_1 = credit_lines[0] unless credit_lines.nil?
      credit_2 = credit_lines[1] unless credit_lines.size < 2
      print_order = PrintOrder.new(:last_name=>self.address.last_name,
                                   :first_name => self.address.first_name,
                                   :performance_code => self.performance_code,
                                   :venue => self.performance.production.venue.name,
                                   :theater => self.theater.name,
                                   :title => self.performance.production.name,
                                   :credit_1 => credit_1,
                                   :credit_2 => credit_2,
                                   :patron_code => self.address.customer_tag,
                                   :performance_date => self.performance.performance_date,
                                   :performance_time => self.performance.performance_time,
                                   :amount=>self.total,
                                   :remote_id => self.id)

      # print_order.save!

      print_order.attributes['line_items_attributes'] ||= []
      print_order.attributes['payments_attributes'] ||= []
      print_order.attributes['tickets_attributes'] ||= []

      self.line_items.select { |li| !li.special_offer_id.nil? || li.ticket_count > 0 }.each { |oli|
        print_order.line_items_attributes << PrintLineItem.new(:order_id => print_order.id,
                                                               :description => oli.receipt_description,
                                                               :amount => oli.receipt_total)
        # print_line_item.save!
      }
      self.payments.size

      self.payments.each { |pay|
        unless pay.receipt_description.blank?
          receipt_payment = ReceiptPayment.new(:order_id => self.print_order_id,
                                               :description => pay.receipt_description,
                                               :amount => pay.customer_visible_amount)
          print_order.payments_attributes << receipt_payment
        end
      }
      self.ticket_line_items.each do |tli|
        tli.ticket_count.times do
          ticket = Ticket.new(:order_id=>self.print_order_id,
                              :ticket_class=>tli.ticket_class.class_code,
                              :type=>'Ticket'
          )
          print_order.tickets_attributes << ticket
          #ticket.save!
        end
      end
      print_order.save!
      self.print_order_id = print_order.id

    end
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


  def exchange_and_process_from!(original_order)
    Order.transaction do
      self.address = original_order.address
      original_order.status = Order::EXCHANGED
      self.status = Order::NEW
      self.save!
      self.update_special_offer_line_items_from_code!
      original_order.release_tickets!
      exchange_payment_on_original_order = original_order.exchange_payments.create!(:amount=>-1*original_order.payments(true).to_a.sum { |p| p.amount }, :note=>original_order.description)
      exchange_payment_on_self = self.exchange_payments.create!(:amount=>-1 * exchange_payment_on_original_order.amount, :payment_id=>exchange_payment_on_original_order.id)
      exchange_payment_on_original_order.update_attribute(:payment_id, exchange_payment_on_self.id)
      payment_difference = self.total - exchange_payment_on_self.amount
      if payment_difference < 0
        self.price_override_payments.create!(:amount=>payment_difference)
      elsif payment_difference > 0
        create_proper_payment_in_amount_of!(payment_difference)
      end
      self.status=Order::PROCESSED
      self.set_email_confirmation
      self.payments(true)
      self.save!

      original_order.save!
    end
  end

  def release_tickets!
    self.ticket_line_items.each { |ti| ti.destroy }
    self.payments.each { |p| p.release_tickets! }
  end

# for form processing
  def production_code=(string)
    @production_code=string
  end

  def production_code()
    self.performance.try(:production).try(:production_code) || @production_code
  end


  def performance_code=(string)
    self.performance=Performance.find_by_performance_code(string)
  end


  def performance_code()
    self.performance.try(:performance_code)
  end

  def total_ticket_quantity
    self.ticket_line_items.inject(0) { |sum, li| sum + li.ticket_count }
  end

  def unique_line_items(reload_line_items = false)
    (super +
        self.ticket_line_items(reload_line_items)
    ).uniq
  end

  protected

  def transition_new_to_fulfilled!(redirect_to = nil)
    redirect_to = self.transition_new_to_processed!(redirect_to)
    self.transition_processed_to_fulfilled!(redirect_to)
  end

  def transition_processing_to_processing!(redirect_to = nil)
    self.transition_new_to_processing!(redirect_to)
  end

  def transition_processed_to_fulfilled!(redirect_to = nil)
    self.send_to_printer
    super
  end

  def applicable_price(regular_ticket_class, offer_ticket_class)
    return [regular_ticket_class.ticket_price, offer_ticket_class.ticket_price].min
  end

  def production_ticket_class_from_offer(offer)
    self.performance.production.ticket_classes.select { |tc| tc.class_code == offer.use_ticket_class_code }.first
  end

  def create_proper_payment_in_amount_of!(amount)
    case self.payment_type
      when FLEX_PASS
        flex_pass = FlexPass.find_by_code(self.flex_pass_code)
        raise 'No FlexPass with that code exists' unless flex_pass
        offer = flex_pass.flex_pass_offer
        if !offer.theater_id.blank? then
          raise "That FlexPass is restricted to #{Theater.find_by_id(offer.theater_id).name} productions" if (offer.theater_id != self.performance.production.theater.id and !offer.exclude_theater?)
          raise "That Flexpass cannot be used for tickets for #{Theater.find_by_id(flex_pass.flex_pass_offer.theater_id).name} productions" if (flex_pass.flex_pass_offer.theater_id == self.performance.production.theater.id and flex_pass.flex_pass_offer.exclude_theater?)

        end
        pass_ticket_class = production_ticket_class_from_offer(offer)
        total_amount = ticket_line_items.inject(0) { |total_amount, li| total_amount += self.applicable_price(li.ticket_class, pass_ticket_class)* li.ticket_count }
        new_payment = FlexPassPayment.new(
            :number_of_tickets => self.ticket_quantity,
            :flex_pass => flex_pass,
            :amount => total_amount
        )
        payments << new_payment
        new_payment.process!
      when MEMBERSHIP
        membership = Membership.find_by_member_code(self.member_code)
        raise "No current membership with that code exists" unless membership
        if !self.address.email.blank? && membership.address.email.downcase.strip != self.address.email.downcase.strip
          raise 'Member ID does not match provided email address'
        end
        raise 'That member ID is not active. Please call the box office for assistance.' unless membership.is_active?
        pass_ticket_class = production_ticket_class_from_offer(membership.membership_offer)
        total_amount = ticket_line_items.inject(0) { |total_amount, li| total_amount += self.applicable_price(li.ticket_class, pass_ticket_class)* li.ticket_count }

        new_payment = MembershipPayment.new(:number_of_tickets=>self.ticket_quantity, :membership=>membership, :amount=>total_amount)
        payments << new_payment
        new_payment.process!
      else
        new_payment = super
    end
    new_payment
  end


  def set_defaults
    self.ticket_line_items.each { |tli| tli.order=self if tli.order.nil? }

  end

  def set_tasks_after_save
    if self.do_not_create_tasks.nil? && self.status_changed?
      super
      case self.status
        when PROCESSED
          create_reminder_task
        when FULFILLED
          create_performance_followup_task
      end
    end

  end

  def create_reminder_task
    if self.contains_tickets? && !self.performance.suppress_notification
      day_before = self.performance.performance_date.to_datetime-1.day
      self.tasks << OutreachTask.new(:execute_at=>day_before, :method_symbol=>:performance_reminder) unless day_before - 1.day < Time.now
    end
  end


  def create_receipt_task
    self.tasks << OutreachTask.new(:execute_at=>Time.now + 5.minutes, :method_symbol=>:ticket_confirmation) unless self.performance.suppress_notification

    super
  end

  def create_performance_followup_task
    if self.contains_tickets? && !self.performance.suppress_notification
      monday_following = self.performance.performance_date.end_of_week + 1.day
      case
        when self.address.current_member?
          self.tasks << OutreachTask.new(:execute_at=>monday_following, :method_symbol=>:member_followup)
        when self.paid_with_pass?
          self.tasks << OutreachTask.new(:execute_at=>monday_following, :method_symbol=>:flex_pass_followup)
        when self.address.first_time_paying?(self)
          self.tasks << OutreachTask.new(:execute_at=>monday_following, :method_symbol=>:first_time_followup)
        else
          self.tasks << OutreachTask.new(:execute_at=>monday_following, :method_symbol=>:standard_followup)
      end
    end
  end


  def set_theater
    self.theater_id = self.performance.production.theater_id
  end

  def remove_empty_ticket_lines
    self.ticket_line_items.each { |li| self.ticket_line_items.delete(li) if li.ticket_count == 0 }
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