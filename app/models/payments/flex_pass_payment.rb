class FlexPassPayment < Payment
  validates_presence_of :flex_pass
  belongs_to :flex_pass
  
  validates_each :number_of_tickets do |record, attr, value|
t    old_number_of_tickets = 0
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
  
  
  def refund!
    raise 'Not Implemented'
  end
end
