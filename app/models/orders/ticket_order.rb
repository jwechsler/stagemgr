class TicketOrder < Order


  has_many :ticket_line_items, :foreign_key => :order_id
  accepts_nested_attributes_for :ticket_line_items, :allow_destroy => true

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
      if (!record.performance.nil? && record.performance.restricted_payment_types.map { |r| r.display_name }.include?(record.payment_type))
        record.errors.add :payment_type, "is not allowed for this event"
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

  def holdable?
    true
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

  def reload_associated
    super
    self.preset_line_items
  end

  def preset_line_items
    super
    unless self.finalized?
      tcs = self.ticket_line_items.map { |li| li.ticket_class_id }
      available = self.performance.ticket_class_allocations.select { |tca| tca.available && !tcs.include?(tca.ticket_class.id) }.map { |tca| tca.ticket_class }.select { |tc| tc.web_visible unless tc.nil? }
      available.each { |tc| self.ticket_line_items.build(:ticket_class => tc, :ticket_count => 0) }
      self.ticket_line_items.sort! { |a, b| a.ticket_class_id <=> b.ticket_class_id }
    end
  end

  def valid_payment_types_for(current_user)
    valid_payment_types = super
    valid_payment_types = valid_payment_types - self.performance.restricted_payment_types.map { |rpt| rpt.display_name } unless self.performance.nil?
    valid_payment_types
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
    unless PrintOrder.site.to_s.blank?
      unless self.print_order_id.nil?
        print_order = PrintOrder.find(self.print_order_id)
        if print_order.status == 'Printed'
          print_order.status = 'Unprinted'
          print_order.reprints += 1
          print_order.save!
        end
      else
        unless self.performance.production.credit_lines.blank?
          credit_lines = self.performance.production.credit_lines.split("\n")
          credit_1 = credit_lines[0] unless credit_lines.nil?
          credit_2 = credit_lines[1] unless credit_lines.size < 2
        end
        print_order = PrintOrder.new(:last_name => self.address.last_name,
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
                                     :amount => self.total,
                                     :remote_id => self.id)

        # print_order.save!

        print_order.attributes['line_items_attributes'] ||= []
        print_order.attributes['payments_attributes'] ||= []
        print_order.attributes['tickets_attributes'] ||= []

        self.unique_line_items.select { |li| !li.special_offer_id.nil? || li.ticket_count > 0 }.each { |oli|
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
            ticket = Ticket.new(:order_id => self.print_order_id,
                                :ticket_class => tli.ticket_class.class_code,
                                :type => 'Ticket'
            )
            print_order.tickets_attributes << ticket
            #ticket.save!
          end
        end
        print_order.save!
        self.print_order_id = print_order.id

      end
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

  def ticketing_fee
    BigDecimal.new(self.ticket_line_items.to_a.sum{|li| li.ticket_class.ticketing_fee * li.ticket_count }.to_s, 2)
  end

  def contains_tickets?
    self.ticket_line_items.select { |li| li.ticket_count > 0 }.size > 0
  end


  def exchange_and_process_from!(original_order)
    Order.transaction do
      self.address = original_order.address
      original_order.status = Order::EXCHANGED
      self.status = Order::NEW
      self.save!
      self.update_special_offer_line_items_from_code!
      original_order.release_tickets!
      exchange_payment_on_original_order = original_order.exchange_payments.create!(:amount => -1*original_order.payments(true).to_a.sum { |p| p.amount }, :note => original_order.description)
      exchange_payment_on_self = self.exchange_payments.create!(:amount => -1 * exchange_payment_on_original_order.amount, :payment_id => exchange_payment_on_original_order.id)
      exchange_payment_on_original_order.update_attribute(:payment_id, exchange_payment_on_self.id)
      payment_difference = self.total - exchange_payment_on_self.amount
      if payment_difference < 0
        self.price_override_payments.create!(:amount => payment_difference)
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

  def sync_to_salesforce!(sf_cache = nil)
    if sf_cache.nil?
      sf_cache = SyncCache.new
    end
    if self.syncable? && (self.sf_last_sync_at.nil? || self.sf_last_sync_at < self.updated_at)
      puts "syncing order #{self.id}"
      event = SalesforceData::Event.find_by_stagemgr_order_id__c(self.id.to_s)
      # is delete needed?
      if self.returned?
        puts "  removing synced copy"
        event.delete unless event.nil?
      elsif prod = sf_cache.production(self.performance.production_id)
        contact = sf_cache.address(self.address_id)

        showtime = DateTime.new(self.performance.performance_date.year,
                                self.performance.performance_date.month,
                                self.performance.performance_date.day,
                                self.performance.performance_time.hour,
                                self.performance.performance_time.min,
                                self.performance.performance_time.sec,
                                Rational(Time.zone.utc_offset/60/60, 24))
        if event.nil?
          puts "  creating event in salesforce"
          event = SalesforceData::Event.create("stagemgr_order_id__c" => self.id.to_s,
                                           "WhatId" => prod.Id,
                                           "IsAllDayEvent" => true,
                                           "ActivityDateTime" => self.performance.performance_date,
                                           "StartDateTime" => self.performance.performance_date,
                                           "Subject" => (self.attended? ? 'Attended' : 'Missed'),
                                           "WhoId" => contact.Id,
                                           "DurationInMinutes" => 1440,
                                           "IsPrivate" => false,
                                           "IsReminderSet" => false,
                                           "OwnerId" => $DATABASEDOTCOM['user_id'],
                                           "ShowAs" => "Free",
                                           "RecordTypeId" => $DATABASEDOTCOM['ticket_order_record_type_id']
          )
        else
          event.WhatId = prod.Id
          event.ActivityDateTime = self.performance.performance_date
          event.StartDateTime = self.performance.performance_date
          event.WhoId = contact.Id
          event.Subject = (self.attended? ? 'Attended' : 'Missed')
          puts "  saving event to salesforce"

        end
        event.save

      end
      self.sf_object = event
      self.sf_last_sync_at = DateTime.now + 15.seconds
      self.save!
    end
  end

  def release_tickets!
    self.ticket_line_items.each { |ti| ti.destroy }
    self.payments.each { |p| p.release_tickets! }
  end

  def reservation_date
    return performance.to_datetime
  end

  def all_line_items(reload_line_items = false)
    super(reload_line_items) + self.ticket_line_items(reload_line_items)
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

  def refund_line_items(reversing_entries)
    reversing_entries.each { |e| self.ticket_line_items << e }
    super(reversing_entries)
  end

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

        new_payment = MembershipPayment.new(:number_of_tickets => self.ticket_quantity, :membership => membership, :amount => total_amount)
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
      self.tasks << OutreachTask.new(:execute_at => day_before, :method_symbol => :performance_reminder) unless day_before - 1.day < Time.now
    end
  end


  def create_receipt_task
    self.tasks << OutreachTask.new(:execute_at => Time.now + 5.minutes, :method_symbol => :ticket_confirmation) unless self.performance.suppress_notification

    super
  end

  def create_notify_refund_task
    self.tasks << NotificationTask.new(:execute_at => Time.now, :notifications => [$EMAIL_ADDRESS['box_office'], $EMAIL_ADDRESS['supervisor_notifications']].join(','),
                                       :method_symbol => :refunded_fulfilled_item_alert)
    super
  end


  def create_performance_followup_task
    if self.contains_tickets? && !self.performance.suppress_notification
      monday_following = self.performance.performance_date.end_of_week + 1.day
      case
        when self.address.current_member?
          self.tasks << OutreachTask.new(:execute_at => monday_following, :method_symbol => :member_followup)
        when self.paid_with_flexpass?
          self.tasks << OutreachTask.new(:execute_at => monday_following, :method_symbol => :flex_pass_followup)
        when self.address.first_time_paying?(self)
          self.tasks << OutreachTask.new(:execute_at => monday_following, :method_symbol => :first_time_followup)
        else
          self.tasks << OutreachTask.new(:execute_at => monday_following, :method_symbol => :standard_followup)
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
      if self.paid_with_flexpass?
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