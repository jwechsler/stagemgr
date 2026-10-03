# Books refunds made outside the app (in the Stripe dashboard) when Stripe
# sends charge.refunded. Money only: each refund becomes one negative payment
# row dated when Stripe made it, and the order is flagged for box office
# review (ReviewFlaggable). Tickets, seats and order status are never touched.
#
# Refunds the app issued itself carry metadata source=stagemgr
# (CreditCardPayment#refund_to_card!) and are skipped, as is any refund
# already booked: payments.stripe_refund_id is unique, so a redelivered or
# concurrent event cannot book the same refund twice.
class StripeRefundRecorder
  SUCCEEDED = 'succeeded'.freeze
  NOTE = 'Refunded in Stripe dashboard'.freeze
  # Stripe caps a list page at 100; no charge has more refunds than that.
  REFUND_LIST_LIMIT = 100
  CENTS_PER_DOLLAR = 100

  class UnmatchedRefund < StandardError; end

  def self.call(charge)
    new(charge).call
  end

  # A refund that was pending when charge.refunded arrived (e.g. the Stripe
  # balance could not cover it) was skipped then; Stripe reports it reaching
  # succeeded with a refund update event, so book its charge's refunds again.
  def self.call_for_refund(refund)
    return unless refund['status'] == SUCCEEDED
    return if refund_source(refund) == CreditCardPayment::REFUND_SOURCE
    return if refund['charge'].blank?

    call(Stripe::Charge.retrieve(refund['charge']))
  end

  # StripeObject has no #dig.
  def self.refund_source(refund)
    metadata = refund['metadata']
    metadata && metadata['source']
  end

  def initialize(charge)
    @charge = charge
  end

  def call
    refunds.each { |refund| record(refund) }
  end

  private

  attr_reader :charge

  # Newer API versions no longer embed refunds on the charge, so list them.
  def refunds
    Stripe::Refund.list({ charge: charge['id'], limit: REFUND_LIST_LIMIT }).data
  end

  def record(refund)
    return unless bookable?(refund)

    source = card_source || recurring_source
    return report_unmatched(refund) if source.nil?
    return if booked_by_legacy_handler?(source, refund)

    Payment.transaction do
      payment = build_refund_row(source, refund)
      payment.save!
      ReviewFlaggable.order_to_review(source.order).flag_for_review!(review_reason(refund))
    end
  rescue ActiveRecord::RecordNotUnique
    # A concurrent delivery of the same event booked it first.
    Rails.logger.info("Stripe refund #{refund['id']} was already recorded")
  end

  def bookable?(refund)
    refund['status'] == SUCCEEDED &&
      refund_source(refund) != CreditCardPayment::REFUND_SOURCE &&
      !already_recorded?(refund['id'])
  end

  # Partial refunds the app issued before stripe_refund_id existed carry the
  # refund id in transaction_id (RefundPayment#process!).
  def already_recorded?(refund_id)
    Payment.where(stripe_refund_id: refund_id)
           .or(Payment.where(type: 'RefundPayment', transaction_id: refund_id)).exists?
  end

  # Legacy: the charge.refunded handler this class replaced booked membership
  # refunds as negative RecurringPayments with no stripe_refund_id. It ran when
  # Stripe sent the event, so any refund created up to the newest such row on
  # the invoice is already on the books.
  def booked_by_legacy_handler?(source, refund)
    return false unless source.is_a?(RecurringPayment)

    booked_through = RecurringPayment.where(type: 'RecurringPayment', transaction_id: source.transaction_id,
                                            stripe_refund_id: nil)
                                     .where('amount < 0').maximum(:created_at)
    booked_through.present? && Time.zone.at(refund['created']) <= booked_through
  end

  def refund_source(refund)
    self.class.refund_source(refund)
  end

  # A one-off card sale stores the PaymentIntent id (older sales the charge
  # id). Type pinned: Payment subclass scopes match every payment type.
  # A split copies the payment onto each new order, so prefer one whose order
  # still holds it and that has something left to refund.
  def card_source
    references = [charge['payment_intent'], charge['id']].compact_blank
    return if references.empty?

    candidates = CreditCardPayment.where(type: 'CreditCardPayment', transaction_id: references)
                                  .where('amount > 0').includes(:order).order(:id).to_a
    candidates.find { |payment| live_order?(payment.order) && payment.refundable_amount.positive? } ||
      candidates.first
  end

  def live_order?(order)
    RefundEligibility::GIVEN_UP_STATUSES.exclude?(order&.status)
  end

  # A membership charge pays a subscription invoice, stored as the
  # RecurringPayment's transaction_id.
  def recurring_source
    invoice_id = invoice_id_for_charge
    return if invoice_id.blank?

    RecurringPayment.where(type: 'RecurringPayment', transaction_id: invoice_id).where('amount > 0').order(:id).first
  end

  # The app's stripe gem (11.x) pins API 2024-04-10, where a charge carries
  # its invoice. The event payload follows the webhook endpoint's API version
  # instead, and from 2025-03-31 charges no longer have the field, so when it
  # is absent ask Stripe: through InvoicePayment once the gem has it, else by
  # re-reading the charge at the pinned version.
  def invoice_id_for_charge
    return charge['invoice'] if charge.keys.include?(:invoice)
    return if charge['payment_intent'].blank?

    if defined?(Stripe::InvoicePayment)
      Stripe::InvoicePayment.list({ payment: { type: 'payment_intent', payment_intent: charge['payment_intent'] },
                                    limit: 1 }).data.first&.invoice
    else
      Stripe::Charge.retrieve(charge['id'])['invoice']
    end
  end

  def build_refund_row(source, refund)
    attributes = { amount: -refund_dollars(refund), processed_on: Time.zone.at(refund['created']),
                   stripe_refund_id: refund['id'], note: NOTE }
    if source.is_a?(CreditCardPayment)
      RefundPayment.new(order: source.order, source_payment: source, payment_type: source.payment_type,
                        confirmation_code: refund['id'], transaction_id: refund['id'], **attributes)
    else
      source.build_refund(**attributes)
    end
  end

  def refund_dollars(refund)
    CurrencyUtils.float_to_currency_decimal(BigDecimal(refund['amount'].to_s) / CENTS_PER_DOLLAR)
  end

  def review_reason(refund)
    date = Time.zone.at(refund['created']).to_date.to_formatted_s(:numeric_month_and_day)
    "Stripe refund #{ActiveSupport::NumberHelper.number_to_currency(refund_dollars(refund))} on #{date}"
  end

  def report_unmatched(refund)
    message = "Stripe refund #{refund['id']} on charge #{charge['id']} matches no payment; it was not recorded"
    Rails.logger.error(message)
    return unless defined?(ExceptionNotifier)

    begin
      raise UnmatchedRefund, message
    rescue UnmatchedRefund => e
      ExceptionNotifier.notify_exception(e, data: { charge_id: charge['id'], refund_id: refund['id'] })
    end
  end
end
