class FlexPassPayment < Payment
  validates_presence_of :flex_pass
  belongs_to :flex_pass

  validates_each :number_of_tickets do |record, attr, value|
    old_number_of_tickets = 0
    unless record.new_record?
      old_number_of_tickets = FlexPassPayment.find(record.id).number_of_tickets
    end
    flex_pass = FlexPass.find(record.flex_pass_id)
    number_of_tickets_left_after_save = flex_pass.number_of_tickets -
                                        flex_pass.flex_pass_payments.sum(:number_of_tickets) -
                                        record.number_of_tickets +
                                        old_number_of_tickets
    record.errors.add attr, "cannot be more than the number of tickets left on flex pass." if number_of_tickets_left_after_save < 0
  end

  def customer_visible_amount
    0.0
  end

  def process!(order = nil)
    offer = self.flex_pass.flex_pass_offer
    if !offer.theater_id.blank? then
      raise "That FlexPass is restricted to #{Theater.find_by_id(offer.theater_id).name} productions" if (!order.theater_ids.include?(offer.theater_id)  and !offer.exclude_theater?)
      raise "That Flexpass cannot be used for tickets for #{Theater.find_by_id(flex_pass.flex_pass_offer.theater_id).name} productions" if (order.theater_ids.include?(flex_pass.flex_pass_offer.theater_id) and flex_pass.flex_pass_offer.exclude_theater?)
    end
    super
  end

  def release_tickets!
    puts('released tickets')
    self.number_of_tickets = 0
    self.save!
  end

  def create_refund_payment(cc_number = nil, note = nil)
      refund_payment = super
      refund_payment.number_of_tickets = 0 - refund_payment.number_of_tickets
      refund_payment
  end

  def note
    "#{self.number_of_tickets} ticket#{self.number_of_tickets != 1 ? 's' : ''}"
  end


end
