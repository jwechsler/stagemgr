class CurrencyPaymentType < PaymentType

def allowed_payment_types_for_exchange(current_user)
    CurrencyPaymentType.all
  end

end
