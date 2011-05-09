module PaymentFormFields
  attr_accessor :credit_card_number,
                :credit_card_type,
                :credit_card_expiration_year,
                :credit_card_expiration_month,
                :credit_card_verification_number,
                :credit_card_confirmation_code,
                :flex_pass_code

  def copy_payment_information(from_order)
    self.credit_card_number = from_order.credit_card_number
    self.credit_card_type = from_order.credit_card_type
    self.credit_card_expiration_year = from_order.credit_card_expiration_year
    self.credit_card_expiration_month = from_order.credit_card_expiration_month
    self.credit_card_confirmation_code = from_order.credit_card_confirmation_code
    self.credit_card_verification_number = from_order.credit_card_verification_number
    self.flex_pass_code = from_order.flex_pass_code

  end

end