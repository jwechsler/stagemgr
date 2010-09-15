module PaymentFormFields
  attr_accessor :credit_card_number,
                :credit_card_type,
                :credit_card_expiration_year,
                :credit_card_expiration_month,
                :credit_card_verification_number

  def build_credit_card_payment_from_payment_form
    self.credit_card_payments.build(
      :card_number=>self.credit_card_number,
      :card_type=>self.credit_card_type,
      :card_expiration_year=>self.credit_card_expiration_year,
      :card_expiration_month=>self.credit_card_expiration_month,
      :card_verification_number=>self.credit_card_verification_number
    )
  end
end