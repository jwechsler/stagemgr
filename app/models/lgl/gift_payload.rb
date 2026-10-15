# frozen_string_literal: true

module Lgl
  # Builds the gift JSON bodies Stagemgr sends to LGL for a processed donation.
  #
  # A gift is a 'Gift' type carrying the external id (stagemgr-<order id>),
  # optional campaign, appeal and event ids, the amount, the date received and
  # the tender. Received, deductible and deposited amounts are all the order
  # total, and the received and deposit dates are the same day, matching the
  # ticketing gifts the house hand-imported into LGL.
  #
  # A refund never deletes or zeroes the gift: it appends a dated note, which
  # refund_noted? detects so the note is written once.
  class GiftPayload
    EXTERNAL_ID_PREFIX = 'stagemgr-'
    GIFT_TYPE_ID = 1
    GIFT_TYPE_NAME = 'Gift'
    REFUND_NOTE_PREFIX = 'Refunded in Stagemgr on'
    # Keyed on payments.type, not display_name, which staff can edit.
    PAYMENT_TYPE_NAMES = { 'CreditCardPayment' => 'Credit Card', 'CashPayment' => 'Cash',
                           'CheckPayment' => 'Check' }.freeze

    def self.external_id(order)
      "#{EXTERNAL_ID_PREFIX}#{order.id}"
    end

    def self.for_create(order, campaign_id:, appeal_id:, event_id:)
      total = order.total.to_f.round(2)
      date = received_date(order)
      gift_type.merge(
        external_id: external_id(order), campaign_id: campaign_id, appeal_id: appeal_id, event_id: event_id,
        received_amount: total, deductible_amount: total, deposited_amount: total,
        received_date: date, deposit_date: date,
        payment_type_name: PAYMENT_TYPE_NAMES[tenders(order).first&.type],
        note: "Stagemgr donation order ##{order.id}"
      ).compact
    end

    def self.refund_note(order, existing_note)
      gift_type.merge(note: [existing_note.presence, "#{REFUND_NOTE_PREFIX} #{refund_date(order)}"].compact.join("\n"))
    end

    def self.refund_noted?(note)
      note.to_s.include?(REFUND_NOTE_PREFIX)
    end

    # default_timezone is :local and time_zone_aware_attributes is false, so
    # processed_on is already the wall-clock time staff see: use to_date,
    # never in_time_zone.
    def self.received_date(order)
      first_paid = tenders(order).map(&:processed_on).compact.min
      (first_paid || order.updated_at).to_date.iso8601
    end

    def self.refund_date(order)
      refunds = order.payments.select { |payment| payment.amount.to_f.negative? }
      refunded = refunds.map(&:processed_on).compact.max
      (refunded || Date.current).to_date.iso8601
    end

    # Positive credit card, cash and check payments, in the order they were made.
    def self.tenders(order)
      order.payments.select { |payment| PAYMENT_TYPE_NAMES.key?(payment.type) && payment.amount.to_f.positive? }
    end

    def self.gift_type
      { gift_type_id: GIFT_TYPE_ID, gift_type_name: GIFT_TYPE_NAME }
    end
    private_class_method :refund_date, :tenders, :gift_type
  end
end
