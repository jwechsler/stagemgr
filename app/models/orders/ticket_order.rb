class TicketOrder < Order

  before_validation :set_tickets_for_pass_redemption
  before_validation :unassign_seats_when_performance_changes, if: :performance_id_changed?
  after_validation do
    if status_changed? && (refunded? || unclaimed?) && performance.production.has_reserved_seating?
      unassign_seats
    end
  end

  before_save :set_theater
  before_save :remove_empty_ticket_lines
  before_save :finalize_seat_assignments

  after_save :update_attendance_record

  before_destroy :unassign_seats
  before_destroy :reverse_source_exchange_payments, if: :exchanging?

  attr_accessor :selected_production

  has_many :ticket_line_items, :foreign_key => :order_id

  belongs_to :exchange_source, class_name: "TicketOrder", foreign_key: "exchange_source_id"
  belongs_to :split_source, class_name: "TicketOrder", foreign_key: "split_source_id"
  accepts_nested_attributes_for :ticket_line_items, allow_destroy: true

  SEATING_REQUESTS = (
    WHEELCHAIR, WHEELCHAIR_TRANSFER, STAIRS =
    'Wheelchair (no transfer)', 'Wheelchair (can transfer)', 'No stairs')

  validates_associated :ticket_line_items
  validates_presence_of :performance

  #before_validation :tickets_available?, :if=>[:processed?, :status_changed?]

  validate :ticket_stock_available, :unless=>:allow_deletion?
  validate :seat_assignments_complete?, :if=>:seating_check_required?
  validate :payments_exist?, :if=>:processed?
  # validate :verify_fully_seated, if: -> { !self.allow_deletion? && performance.production.has_reserved_seating? && (status.eql?(Order::PROCESSED) || status.eql?(Order::FULFILLED))}
  validates :uuid, presence: true

  validates_each :status do |record, attr, value|
    unless record.allow_deletion?
      if value == PROCESSED
        unless record.ticket_line_items.empty? || record.number_of_tickets > 0
          record.errors.add :ticket_line_items, "must contain at least one ticket."
        end
        if (!record.performance.nil? && record.performance.restricted_payment_types.include?(record.payment_type))
          record.errors.add :payment_type, "is not allowed for this event"
        end
      end
    end
  end

  def ticket_stock_available
    unless self.ticket_line_items.empty?
      ticket_counts_by_class = Hash.new
      self.ticket_line_items.each do |tli|
        errors.add :base, "Missing allocation for #{self.performance.performance_code} / #{tli.ticket_class.nil? ? "NIL" : tli.ticket_class.class_code}" unless self.performance.ticket_class_allocations.map{|tla| tla.ticket_class }.include?(tli.ticket_class)
        if ticket_counts_by_class.has_key?(tli.ticket_class_id)
          ticket_counts_by_class[tli.ticket_class_id] += tli.ticket_count
        else
          ticket_counts_by_class[tli.ticket_class_id] = tli.ticket_count
        end
      end
      ticket_counts_by_class.keys.each do |key|
        allocation = TicketClassAllocation.find_by_performance_id_and_ticket_class_id(self.performance_id, key)
        unless allocation.nil?
          number_of_tickets_already_used = TicketLineItem.where('ticket_class_id = ? and performance_id = ? and order_id != ?',key, self.performance_id, self.id).joins(:order).sum(:ticket_count)
          if (!allocation.ticket_limit.nil? && (ticket_counts_by_class[key] + number_of_tickets_already_used > allocation.ticket_limit)) then
            remainder = allocation.ticket_limit - number_of_tickets_already_used
            if remainder > 0
              errors.add :base, "There are only #{allocation.ticket_limit - number_of_tickets_already_used} '#{TicketClass.find(key).class_name}' tickets remaining."
            else
              errors.add :base, "Sorry, there are no '#{TicketClass.find(key).class_name}' tickets left."
            end
          end
        end
      end
      seats_left = self.performance.number_of_seats_left(self)
      errors.add :base, "There #{seats_left == 1 ? "is" : "are"} only #{seats_left} reservation#{"s" unless seats_left == 1} remaining for the #{self.performance.performance_date.to_s} performance at #{self.performance.performance_time.to_formatted_s(:standard_time)}." if self.holding_seats? && seats_left < self.number_of_seats
    end
  end

  def payments_exist?
    self.payments.size > 0
  end

  def unassign_seats
    Rails.logger.info("Releasing seats for Order #{self.id} [#{self.status}] [#{self.seats.map{|s| s.seat.location}.join(',')}]")
    self.seats.each {|seat| seat.unassign_from_order(self.uuid); seat.save! }
    Rails.logger.info("Seats released for Order #{self.id} [#{self.status}] [#{self.seats.map{|s| s.seat.location}.join(',')}]")
  end

  def unassign_seats_when_performance_changes
    self.seats.reload.each {|seat|
      unless seat.performance_id.eql?(self.performance_id)
        seat.unassign_from_order(self)
      end
    }
    self.seats.reload
  end

  # def verify_fully_seated
  #   unless seat_assignments_complete?
  #     errors.add :base, "You must select #{self.number_of_seats} #{'seat'.pluralize(self.number_of_seats)} before finalizing this order"
  #   end
  # end

  def seat_assignments_complete?
    unless self.performance.nil?
      if self.performance.production.has_reserved_seating? then
        if (self.seats.reload.size != self.number_of_seats) then
          self.errors.add :seats, " do not match tickets in order (#{self.number_of_seats} required)"
          return false
        end
      end
    end
    return true
  end

  def seatable?
    [Order::NEW, Order::PROCESSED, Order::PROCESSING, Order::EXCHANGING, Order::HOLD].include?(self.status) && performance.production.has_reserved_seating?
  end

  def theater_ids
    [performance.production.theater.id]
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

  def contains_exchangeable_tickets?
    self.ticket_line_items.select{|tli| tli.ticket_class.exchangeable?}.count > 0
  end

  def exchangeable?
    self.status == Order::PROCESSED || self.status == Order::FULFILLED || self.status == Order::UNCLAIMED
  end

  def splittable?
    self.number_of_tickets > 1 && [Order::PROCESSED, Order::UNCLAIMED, Order::FULFILLED].include?(self.status) && !self.paid_with_membership?
  end

  def exchanged?
    self.status == Order::EXCHANGED
  end

  def exchanging?
    self.status.eql?(Order::EXCHANGING)
  end

  def split?
    self.status.eql?(Order::SPLIT)
  end

  def in_transactional_state?
    super || [Order::RELEASING, Order::EXCHANGING].include?(status)
  end

  def refundable?
    self.exchangeable?
  end

  def holdable?
    true
  end

  def editable?
    (self.status == Order::EXCHANGING) || super
  end

  def holding_seats?
    ![Order::UNCLAIMED, Order::CANCELED].include?(self.status)
  end

  def processed_or_fulfilled?
    self.processed? || self.fulfilled?
  end

  def seating_check_required?
    self.processing? || processed_or_fulfilled?
  end

  def assigned_seats?
    result = false
    self.ticket_line_items.each {|tli| result ||= tli.ticket_class.assigns_seats? }
    result
  end

  def wheelchair_requested?
    case
      when [WHEELCHAIR, WHEELCHAIR_TRANSFER].include?(self.special_request) then true
      when self.seats.select{|sa| !sa.accessibility.blank?}.size > 0 then true
      else false
    end
  end

  def seat_assignments(assignment_types = [])
    unless self.performance.nil?
      if self.performance.production.has_reserved_seating?
        show_seats = assignment_types.size.eql?(0) ? self.seats : self.seats.select {|s| assignment_types.include?(s.status)}
        r = show_seats.map { |s| s.seat.location }.sort.join(', ')
      elsif self.assigned_seats?
        r = "#{self.ticket_detail_description}"
      else
        r = ""
      end
    else
      r = ""
    end
    r
  end

  # when an order is saved to any status besides "EXCHANGING", any temporary seat assignments
  # are also associated with the newly generated order_id
  def finalize_seat_assignments
    if status_changed? and self.processed? and self.performance.production.has_reserved_seating? and !self.uuid.nil?
      SeatAssignment.assign_seats_to_saved_order(self.uuid) unless self.exchanging?
    end
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
      tcs = self.ticket_line_items.map { |li| li.ticket_class_id }.uniq
      available = self.performance.ticket_class_allocations.select { |tca| tca.available? && !tcs.include?(tca.ticket_class.id) && tca.ticket_class.web_visible? }.map { |tca| tca.ticket_class }
      available.each { |tc| self.ticket_line_items.build(:ticket_class => tc, :ticket_count => 0) }
      self.ticket_line_items.order(:ticket_class_id)
    end
  end

  def valid_payment_types_for(current_user)
    valid_payment_types = super
    valid_payment_types = valid_payment_types - self.performance.restricted_payment_types unless self.performance.nil?
    valid_payment_types
  end

  def ticket_detail_description
    self.ticket_line_items.select{|tli| !tli.ticket_count.nil? && tli.ticket_count> 0}.map { |li|
      if (li.ticket_count.nil? ? 0 : li.ticket_count) > 0
        li.to_s
      else
        ""
      end
    }.join(', ')
  end

  # @todo remove when multiple performances for an order are allowed
  def performances
    [self.performance]
  end

  def associated_theater_id
    if self.performance.nil?
      super
    else
      self.performance.production.theater_id
    end
  end

  def send_to_printer
    unless PrintOrder.site.to_s.blank?
      unless self.print_order_id.nil?
        print_order = PrintOrder.find(self.print_order_id)

        print_order.status = 'Unprinted'
        print_order.reprints += 1
        seat_index = 0
        if self.performance.production.has_reserved_seating? then
          print_order.tickets.each do |ticket|
            ticket.seat = self.seats[seat_index].seat.location
            seat_index += 1
            ticket.save!
          end
         end
        print_order.save!
      else
        unless self.performance.production.credit_lines.blank?
          credit_lines = self.performance.production.credit_lines.split("\n")
          credit_1 = credit_lines[0] unless credit_lines.nil?
          credit_2 = credit_lines[1] unless credit_lines.size < 2
        end

        cleaned_name, f_name, m_name, l_name, f_name2 = Address.parse_name(self.hold_under.blank? ? self.address.full_name : self.hold_under)
        unless cleaned_name == self.address.full_name
          use_last_name = l_name
          use_first_name = f_name
        else
          use_last_name = self.address.last_name
          use_first_name = self.address.first_name
        end
        print_order = PrintOrder.new(:last_name => use_last_name,
                                     :first_name => use_first_name,
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
        tli_index = 0
        self.ticket_line_items.each do |tli|
          tli.ticket_count.times do
            ticket = Ticket.new(:order_id => self.print_order_id,
                                :ticket_class => tli.ticket_class.class_code,
                                :type => 'Ticket',
                                :seat => seats[tli_index].nil? ? "" : seats[tli_index].seat.location
            )
            tli_index += 1
            print_order.tickets_attributes << ticket
            #ticket.save!
          end
        end
        print_order.save!
        self.print_order_id = print_order.id

      end
    end
  end

  def number_of_tickets
    if self.ticket_line_items.empty?
      result = 0
    else
      result = self.ticket_line_items.inject(0) { |sum, li| sum + (li.ticket_count.nil? ? 0 : li.ticket_count) }
    end
    return result || 0
  end

  def number_of_seats
    if self.ticket_line_items.empty?
      0
    else
      self.ticket_line_items.select {|tli| !tli.nil? && !tli.ticket_class.nil? && tli.ticket_class.holds_seats?}.inject(0) { |sum, li| sum + (li.ticket_count.nil? ? 0 : li.ticket_count)}
    end
  end

  #
  # Returns a hashmap of each individual ticket with a reference to it's source ticket_line_item
  # and an associated seat.  Used for splitting seats
  #

  def flatten_ticket_line_items
    tickets = []
    self.adjust_seating_to_match_ticket_line_items
    seat_assignments = self.seats.map{|sa| sa}
    self.ticket_line_items.each do |tli|
      tli.ticket_count.times {
        seat = nil
        if seat_assignments.map{|sa| sa.ticket_class_id}.include?(tli.ticket_class_id)
          seat = seat_assignments.select{|sa| sa.ticket_class_id == tli.ticket_class_id}.first
          seat_assignments.delete_at(seat_assignments.index(seat))
        end
        item = {source: tli, seat:seat, ticket_class_id: tli.ticket_class_id}
        tickets << item
      }
    end
    tickets
  end

  def self.create_ticket_line_item_for_split(original_ticket_line_item, ticket_class_id, seat_assignment = nil)
    unless seat_assignment.nil?
      seat_assignment.ticket_class_id = ticket_class_id
      seat_assignment.save!
    end
    return {source: original_ticket_line_item, seat: seat_assignment, ticket_class_id: ticket_class_id}
  end

  def flatten_payments
    fpayments = Hash.new
    self.payments.each do |payment|
      if fpayments.key?(payment.payment_type_id)
        fpayments[payment.payment_type_id].amount += payment.amount
      else
        fpayments[payment.payment_type_id] = payment.dup
      end
    end
    return fpayments
  end

  # utility routine for ticket splits
  def move_ticket_to_split(tli_hash, split_order, order_face_value, transfer_amount,  original_payments, split_payments)
    dup_tli = tli_hash[:source].dup
    dup_tli.order_id = nil
    dup_tli.ticket_count = 1
    offset = dup_tli.dup
    offset.ticket_count = -1
    dup_tli.price_override = order_face_value.eql?(0.0) ? BigDecimal.new(0.0, 2) : (dup_tli.price/order_face_value*transfer_amount)
    dup_tli.generated_from_split = true
    total = dup_tli.price_override

    loop do

      source_payment_key = original_payments.keys[0]
      source_payment = original_payments.values[0]
      unless source_payment.nil?
        credit = [source_payment.amount,total].min
        offset_payment = source_payment.new_offset_payment(credit, 1)
        self.payments << offset_payment
        if split_payments.key?(source_payment_key)
          split_payments[source_payment_key].amount += offset_payment.new_offset_payment.amount
          split_payments[source_payment_key].number_of_tickets += offset_payment.new_offset_payment.number_of_tickets unless split_payments[source_payment_key].number_of_tickets.nil?
        else
          split_payments[source_payment_key] = offset_payment.new_offset_payment
          # split_payments[source_payment_key] = offset_payment.new_offset_payment

        end
        total -= credit
      end
      original_payments.delete(source_payment_key) if ((!source_payment.nil? || source_payment.amount == 0 ) && (original_payments.size > 1))
      break if total.eql?(0.0)
    end
    dup_tli.order = split_order
    split_order.ticket_line_items << dup_tli
    unless tli_hash[:seat].nil?
      tli_hash[:seat].order_uuid =split_order.uuid
      tli_hash[:seat].save!
      split_order.seats << tli_hash[:seat]
    end
    self.ticket_line_items << offset
  end

  # split a ticket order into two like orders.  The current order has all its tickets removed
  #
  # params:
  # new_tlis -- an array of hashes from the original order with ticket_line_item and seat (see flatten_ticket_items)
  def split(new_tlis, all_tlis = nil)
    TicketOrder.transaction do
      total_transfer_amount = self.total - self.service_line_items.sum(:amount)
      face_value_of_tickets = self.total_ticket_face_value
      original_payment_hash = self.flatten_payments

      order1 = self.fork_order_into_split
      order2 = self.fork_order_into_split
      order1_payments = Hash.new
      order2_payments = Hash.new
      remaining_tickets = all_tlis || self.flatten_ticket_line_items
      index = 0
      new_tlis.each do |tli_hash|
        find_index = remaining_tickets.find_index(tli_hash)
        throw "Can't split order because request for seats improperly generated" if find_index.nil?
        self.move_ticket_to_split(tli_hash, order1, face_value_of_tickets, total_transfer_amount, original_payment_hash, order1_payments)
        remaining_tickets.delete_at(find_index)
      end
      remaining_tickets.each do |tli_hash|
        self.move_ticket_to_split(tli_hash, order2, face_value_of_tickets, total_transfer_amount, original_payment_hash, order2_payments)
      end
      self.status = SPLIT
      self.cancel_pending_tasks
      self.save!
      order1_payments.each_value {|p| order1.payments << p }
      order2_payments.each_value {|p| order2.payments << p }
      order1.payments[0].save!
      order1.print_order_id = nil
      order2.print_order_id = nil
      order1.save!
      order2.save!
      return [order1, order2]
    rescue ActiveRecord::RecordInvalid => e
      self.errors.add(:base, "Could not split order: #{e.message}")
      Rails.logger.debug(e)
    end
    return [nil, nil]
  end

  # Returns orders that this was split to
  #
  def split_to_orders
    if self.split?
      TicketOrder.where(split_source_id: self.id).all
    else
      TicketOrder.where(split_source_id: -1).all
    end
  end

  def performance_code=(string)
    self.performance=Performance.find_by_performance_code(string)
  end

  def number_of_tickets_of_all_payments
    number_of_tickets = self.payments.to_a.sum { |fpp| fpp.number_of_tickets.nil? ? 0 : fpp.number_of_tickets }
    number_of_tickets = 0 if number_of_tickets.nil?
    number_of_tickets
  end

  def attended?
    [PROCESSED, FULFILLED].include?(self.status)
  end

  def ticket_quantity_by_class(class_code)
    self.ticket_line_items.to_a.sum { |li| li.ticket_class.class_code == class_code ? li.ticket_count : 0 }

  end

  def ticketing_fee
    super + BigDecimal.new(self.ticket_line_items.to_a.sum{|li| li.ticket_class.ticketing_fee * li.ticket_count }.to_s, 2)
  end

  def contains_tickets?
    self.ticket_line_items.select { |li| li.ticket_count > 0 }.size > 0
  end

  def exchanged_for
    o = Order.where(exchange_source_id: self.id)
    if o.empty?
      nil
    else
      o.first
    end
  end

  def create_offset_payments
    sorted = self.payments.sort{ |a,b| b.amount <=> a.amount }
    service_fee = self.service_line_items.sum(:amount)
    offsets = Array.new
    offsets = sorted.map do |p|
      offset = p.new_exchange_offset_payment
      if service_fee > 0 then
        diff = [-service_fee, offset.amount].max
        offset.amount -= diff
        service_fee += diff
      end
      offset
    end
    offsets.select{|p|  (p.amount != 0)}
  end

  def total_ticket_face_value(reload_line_items=false)
    a = self.ticket_line_items.to_a.sum { |line_item| line_item.respond_to?(:total) ? line_item.total : 0 }
    a = 0.0 if a < 0.0
    a
  end

  def begin_exchange!(original_order)
    Order.transaction do
      self.exchange_source = original_order
      self.address = original_order.address
      self.status = Order::EXCHANGING
      self.exchange_source.status = Order::RELEASING

      exchange_payments_on_original_order = original_order.create_offset_payments
      exchange_payments_toward_exchange_order = self.payment_type.build_exchange_offset_payments(exchange_payments_on_original_order)
      exchange_payments_on_original_order.each {|p| original_order.payments << p unless p.nil? }
      exchange_payments_toward_exchange_order.each { |p| self.payments << p unless p.nil? }
      payment_difference = self.value_of_all_line_items - exchange_payments_toward_exchange_order.inject(0){|sum, x| sum = sum + x.amount }
      if payment_difference < 0
        self.payments << PriceOverridePayment.new(:amount => payment_difference, :order=>self, :source_payment_type=>original_order.payment_type)
      elsif payment_difference > 0
        self.create_proper_payment_in_amount_of!(payment_difference)
      end

      self.update_special_offer_line_item_from_code!
      self.save!
    end
  end


  def transition_processing_to_exchanging!
    self.transition_processing_to_processing!
  end

  def transition_exchanging_to_processed!
    Order.transaction do
      original_order = self.exchange_source
      self.status=Order::PROCESSED
      self.set_email_confirmation
      self.payments(true)
      self.save!
      original_order.status = Order::EXCHANGED
      original_order.release_tickets!
      original_order.save!
    end
  end

  def exchange_and_process_from!(original_order)
    Order.transaction do
      self.begin_exchange!(original_order)
      self.transition_exchanging_to_processed!
    end
  end

  def release_tickets!
    self.ticket_line_items.each { |ti| ti.destroy }
    self.unassign_seats
    self.payments.each { |p| p.release_tickets! }
  end

  def reservation_date
    return performance.performance_date
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

  def unique_line_items(reload_line_items = false)
    (super +
        self.ticket_line_items(reload_line_items)
    ).uniq
  end

  def production_ticket_class_from_offer(offer)
    self.performance.production.ticket_classes.select { |tc| tc.class_code == offer.use_ticket_class_code }.first
  end

  def create_default_service_fees
    unless self.performance.nil?
      self.performance.production.service_item_templates_new.each do |template|
        self.service_line_items.build(template.attributes_for_service_item)
      end
    end
    self.service_line_items
  end

  def create_exchange_service_fees(original_order)
    templates = Array.new

    if original_order.exchange_source.nil?
      templates = original_order.performance.production.service_item_templates_first_exchange
    else
      templates = original_order.performance.production.service_item_templates_addl_exchange
    end
    templates.each do |template|
      self.service_line_items.build(template.attributes_for_service_item)
    end
    self.service_line_items
  end

  # Alter altering tickets, seating tags must be adjusted if necessary
  #
  # @new_tlis -- Can be either an array of newly created ticket_line_items or s single ticket_line_item
  # @old_tlis -- Can be either an array of previous  ticket_line_items or s single ticket_line_item
  #
  # Notes:
  #   If either new_tlis or old_tlis are nil, then the seating is forced to match the existing ticket line items ticket assignments blindly.
  def adjust_seating_to_match_ticket_line_items(new_tlis = nil, old_tlis =nil)
    if self.performance.production.has_reserved_seating?
      ticket_classes_to_shift = Hash.new
      if new_tlis.nil?
        tli_ticket_class_ids = Set.new(self.ticket_line_items.map{|tli| tli.ticket_class_id})
      else
        new_tlis = [new_tlis] unless new_tlis.kind_of?(Array)
        tli_ticket_class_ids = Set.new(new_tlis.map{|tli| tli.ticket_class_id})
      end
      seat_ticket_class_ids = Set.new(self.seats.map{|s| s.ticket_class_id})

      if old_tlis.nil?
        tc_ids_for_reassign = seat_ticket_class_ids - tli_ticket_class_ids
        old_tlis = self.ticket_line_items.select{|tli| tc_ids_for_reassign.include?(tli.ticket_class_id)}
      else
        old_tlis = [old_tlis] unless old_tlis.kind_of?(Array)
        tc_ids_for_reassign = Set.new(old_tlis.map{|tli| tli.ticket_class_id})
      end
      tc_ids_to_fix = tli_ticket_class_ids - seat_ticket_class_ids # ticket_class_ids that don't exist in seat
      new_tlis = self.ticket_line_items.select{|tli| tc_ids_to_fix.include?(tli.ticket_class_id)} if new_tlis.nil?

      tc_id_pool = []
      new_tlis.each do |tli|
        tli.ticket_count.times do
          tc_id_pool.push(tli.ticket_class_id)
        end
      end

      self.seats.select{|sa| tc_ids_for_reassign.include?(sa.ticket_class_id)}.each do |seat_assignment|
        seat_assignment.ticket_class_id = tc_id_pool.pop
      end
    end
  end

  protected

  def fork_order_into_split
    result = self.dup
    result.uuid = SecureRandom.uuid
    result.do_not_create_tasks = true
    result.split_source_id = self.id
    self.tasks.each {|task| result.tasks << task.dup}
    result
  end

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

  def transition_processing_to_hold!(redirect_to = nil)
    self.transition_new_to_hold!(redirect_to)
  end

  def transition_new_to_hold!(redirect_to = nil)
    self.status = Order::HOLD
    self.save!
    redirect_to
  end

  def transition_processed_to_fulfilled!(redirect_to = nil)
    Resque.enqueue(PrintTicketOrder, self.id)
    super
  end

  def transition_fulfilled_to_unclaimed!(redirect_to = nil)
    self.transition_processed_to_unclaimed!(redirect_to = nil)
  end

  def transition_processed_to_unclaimed!(redirect_to = nil)
    self.unclaimed!
  end

  def self.applicable_price(regular_ticket_class, offer_ticket_class)
    return [regular_ticket_class.ticket_price, offer_ticket_class.ticket_price].min
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
    if self.do_not_create_tasks.nil? || (self.contains_tickets? && !self.performance.suppress_notification)
      day_before = self.performance.performance_date.to_datetime-1.day
      self.tasks << OutreachTask.new(:execute_at => day_before, :method_symbol => :performance_reminder) unless day_before - 1.day < Time.now
    end
  end


  def create_receipt_task
    self.tasks << OutreachTask.new(:execute_at => Time.now + 5.minutes, :method_symbol => :ticket_confirmation) unless (self.performance.suppress_notification || self.suppress_receipt? || !self.do_not_create_tasks.nil?)
    if !$EMAIL_ADDRESS.nil? && !$EMAIL_ADDRESS['wheelchair_conversion_notifications'].blank? && self.wheelchair_requested?
      self.tasks << NotificationTask.new(:execute_at => Time.now + 15.minutes,
                                        :notifications => $EMAIL_ADDRESS['wheelchair_conversion_notifications'],
                                        :method_symbol => :wheelchair_conversion_alert)
    end
    super
  end

  def create_notify_refund_task
    self.tasks << NotificationTask.new(:execute_at => Time.now, :notifications => [$EMAIL_ADDRESS['box_office'], $EMAIL_ADDRESS['supervisor_notifications']].join(','),
                                       :method_symbol => :refunded_fulfilled_item_alert) unless ($EMAIL_ADDRESS.nil? || !self.do_not_create_tasks.nil?)
    super
  end


  def create_performance_followup_task
    if self.do_not_create_tasks.nil?
      if self.contains_tickets? && !self.performance.suppress_notification && self.performance.production.use_ticket_email_templates?
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
  end

  def suppress_receipt?
    self.performance.suppress_notification || self.ticket_line_items.map { |tli|
      tli.ticket_class.suppress_receipt? }.all?
  end


  def remove_empty_ticket_lines
    ticket_classes = self.ticket_line_items.map{|li| li.ticket_class.id }.uniq
    self.ticket_line_items.each do |li|
      self.ticket_line_items.delete(TicketLineItem.find(li.id)) if (li.ticket_count == 0 && !li.id.nil?)
    end
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
        new_line_item.price_override = TicketOrder.applicable_price(li.ticket_class, new_ticket_class) if new_ticket_class.ticket_type == TicketClass::DONATION
        self.ticket_line_items << new_line_item
        self.ticket_line_items.delete(li)
        self.adjust_seating_to_match_ticket_line_items(new_line_item, li)
      }
    end
  end

  def update_attendance_record
    if self.status_changed?
      case self.status
      when Order::FULFILLED
        attendee = self.address
        attendee.productions << self.performances.map {|perf| perf.production}
      when Order::REFUNDED, Order::UNCLAIMED
          self.performances.map { |perf| perf.production }.select {|p| is_unique_visit?(p) }.each {|p|
            self.address.productions.delete(p)
          }
      end

    end
  end

  def reverse_source_exchange_payments
    exchange_source.payments.select{|p| p.can_cancel? }.each{|p|
      p.destroy!
    }
    exchange_source.status = Order::PROCESSED
    exchange_source.save!
  end

  def is_unique_visit?(prod)
    Order.joins(:performance).where("performances.production_id = ? and orders.id != ? and orders.status = ? and orders.address_id = ?",
      prod.id,
      self.id,
      Order::FULFILLED,
      self.address_id).count == 0
  end

  def set_tickets_for_pass_redemption
   if self.status_changed? && self.status == Order::PROCESSED
     if self.paid_with_flexpass?
       flex_pass = self.paid_with_flexpass
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

  def debug_logger
    @@debug_logger ||= Logger.new("#{Rails.root}/log/debug.log")
  end


end


# Salesforce engine bits

class TicketOrder

  def queue_sf_sync(delay = nil)
    delay = 2.minutes if delay.nil?
    Resque.enqueue_in(delay, SyncOrderToSalesforce, self.id)
    super
  end

  def sync_to_salesforce!(sf_cache = nil)
    if sf_cache.nil?
      sf_cache = SyncCache.new
    end
    if self.syncable?
      event = SalesforceData::OrderActivity__c.find_by_stagemgr_order_id__c(self.id)
      # is delete needed?
      if self.returned?
        event.delete unless event.nil?
      elsif
        contact = sf_cache.address(self.address_id)  # May update/create address on salesforce as this point
        showtime = Time.local(self.performance.performance_date.year,
                                self.performance.performance_date.month,
                                self.performance.performance_date.day,
                                self.performance.performance_time.hour,
                                self.performance.performance_time.min,
                                self.performance.performance_time.sec)
        if event.nil?
          event = SalesforceData::OrderActivity__c.create("stagemgr_order_id__c" => self.id.to_s,
            "Name" => self.performance.production.name,
            "Attendee__c" => contact.Id,
            "number_of_tickets__c" => self.number_of_tickets,
            "spent__c" => self.total_paid,
            "attended_on__c" => showtime)
        else
          event.Attendee__c = contact.Id
          event.Name = self.performance.production.name
          event.number_of_tickets__c = self.number_of_tickets
          event.spent__c = self.total_paid
          event.attended_on__c = showtime
        end
        event.save
      end
      self.sf_object = event
      self.sf_order_id = nil || (self.sf_object.Id unless self.sf_object.nil?)
      self.sf_last_sync_at = DateTime.now
      self.save!
    end
  end

end
