# frozen_string_literal: true

module Lgl
  # Classifies a constituent's LGL gifts as a lapsed donor, by fiscal year:
  #
  # - LYBUNT ("last year but unfortunately not this"): gave in the last fiscal
  #   year but not yet in the current one.
  # - SYBUNT ("some year but unfortunately not this"): gave in some earlier
  #   fiscal year, but in neither the last nor the current one.
  # - nil: gave in the current fiscal year, or never gave.
  #
  # Only money received counts (COUNTED_GIFT_TYPES); pledges, in-kind gifts,
  # soft/peer credits and other income do not. A gift with a zero or negative
  # amount (a void or refund) or a blank or unparseable date is ignored, as is
  # one dated in a fiscal year after the current one.
  #
  # The fiscal year containing a date starts on the 1st of
  # +fiscal_year_start_month+ (TheaterInfo#fiscal_year_start_month). Pure: no
  # HTTP, no database.
  class GiftHistory
    LYBUNT = 'LYBUNT'
    SYBUNT = 'SYBUNT'
    COUNTED_GIFT_TYPES = ['Gift', 'Installment', 'Matching', 'In Honor of', 'In Memory of'].freeze

    def self.classify(gifts, today: Date.current, fiscal_year_start_month: TheaterInfo.fiscal_year_start_month)
      new(fiscal_year_start_month).classify(gifts, today)
    end

    def initialize(fiscal_year_start_month)
      @start_month = fiscal_year_start_month
    end

    def classify(gifts, today)
      current = fiscal_year(today)
      years = counted_dates(gifts).map { |date| fiscal_year(date) }.select { |year| year <= current }
      return nil if years.empty? || years.include?(current)

      years.include?(current - 1) ? LYBUNT : SYBUNT
    end

    private

    # Identified by the calendar year the fiscal year starts in.
    def fiscal_year(date)
      date.month >= @start_month ? date.year : date.year - 1
    end

    def counted_dates(gifts)
      Array(gifts).filter_map do |gift|
        next unless COUNTED_GIFT_TYPES.include?(gift['gift_type_name'])
        next unless gift['amount'].to_f.positive?

        gift_date(gift['date'])
      end
    end

    def gift_date(value)
      return nil if value.blank?

      Date.iso8601(value.to_s)
    rescue Date::Error
      nil
    end
  end
end
