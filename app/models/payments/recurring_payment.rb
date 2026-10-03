class RecurringPayment < Payment
  def receipt_description
    'Payment'
  end

  def calculate_processing_fee
    (0.22 + (amount * 0.022)).round(2)
  end

  # A refund of this invoice payment made in the Stripe dashboard
  # (StripeRefundRecorder): a negative copy dated when Stripe refunded it.
  def build_refund(**attributes)
    refund = dup_for_refund
    refund.ipn_track_id = nil
    refund.assign_attributes(attributes)
    refund
  end
end
