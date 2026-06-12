class FlexPassPayment < PassPayment
  validates :flex_pass, presence: true, if: -> { number_of_tickets != 0 }
  belongs_to :flex_pass, inverse_of: :flex_pass_payments

  validates_each :number_of_tickets do |record, attr, value|
    # check for number of tickets allowed
    if record.number_of_tickets > 0 then
      old_number_of_tickets = 0
      unless record.new_record?
        old_number_of_tickets = FlexPassPayment.find(record.id).number_of_tickets
      end
      flex_pass = FlexPass.find(record.flex_pass_id)
      number_of_tickets_left_after_save = flex_pass.number_of_tickets -
                                          flex_pass.flex_pass_payments.sum(:number_of_tickets) -
                                          record.number_of_tickets +
                                          old_number_of_tickets
      record.errors.add(attr, "cannot be more than the number of tickets left on flex pass.") if number_of_tickets_left_after_save < 0

      offer = flex_pass.flex_pass_offer
      unless offer.maximum_uses_per_production.nil? || offer.maximum_uses_per_production.eql?(0)
        production = record.order.performance.production
        already = FlexPassPayment.includes(order: [:performance=>:production]).references(order: [:performance=>:production]).where("flex_pass_id = :flex_pass_id and performances.production_id = :production_id AND orders.status NOT IN (:non_reserving_statuses) and orders.id <> :order_id",flex_pass_id: record.flex_pass_id, production_id: production.id, non_reserving_statuses: Order.non_reserving_statuses, order_id: record.order.id ).sum(:number_of_tickets)
        record.errors.add(attr, " has been exceeded for #{record.order.performance.production.name}.  This flex pass can only be redeemed for #{offer.maximum_uses_per_production} ticket(s)/production, #{record.number_of_tickets + already} requested") if (already + record.number_of_tickets) > offer.maximum_uses_per_production
      end
    end
  end

  def customer_visible_amount
    0.0
  end

  def payment_info
    self.flex_pass.code
  end

  def process!(order = nil)
    offer = self.flex_pass.flex_pass_offer
    if !offer.theater_id.blank? then
      raise "That FlexPass is restricted to #{Theater.find_by_id(offer.theater_id).name} productions" if (!order.theater_ids.include?(offer.theater_id)  and !offer.exclude_theater?)
      raise "That Flexpass cannot be used for tickets for #{Theater.find_by_id(flex_pass.flex_pass_offer.theater_id).name} productions" if (order.theater_ids.include?(flex_pass.flex_pass_offer.theater_id) and flex_pass.flex_pass_offer.exclude_theater?)
    end
    tc_list = order.performance.ticket_class_allocations.select { |tca| tca.available }.map { |tca| tca.ticket_class.class_code }
    raise "#{offer.name} passes cannot be used for this particular performance (#{offer.use_ticket_class_code} restricted). Please contact our box office for details."  unless tc_list.include?(offer.use_ticket_class_code)
    super
  end

  def release_tickets!
    self.number_of_tickets = 0
    self.save!
  end

  def create_refund_payment(cc_number = nil, note = nil)
    refund_payment = super
    refund_payment.flex_pass = self.flex_pass
    refund_payment
  end

  def note
    "#{self.number_of_tickets} ticket#{self.number_of_tickets != 1 ? 's' : ''}"
  end

  def receipt_description
    "#{self.number_of_tickets} FlexPass"
  end

  def new_exchange_offset_payment
    offset_payment = super
   offset_payment.flex_pass = self.flex_pass
   offset_payment
 end
end
