class FlexPassOffer < ApplicationRecord
  belongs_to :theater, optional: true, inverse_of: :flex_pass_offers
  belongs_to :festival, optional: true, inverse_of: :flex_pass_offers
  has_many :flex_passes, inverse_of: :flex_pass_offer
  has_many :flex_pass_line_items, inverse_of: :flex_pass_offer

  include Taggable

  has_tags :flex_pass_offer_tags

  # status_* naming (rather than a scope named "active") avoids shadowing the
  # boolean active attribute and stays parallel with SpecialOffer's scopes.
  scope :status_active,   -> { where(active: true) }
  scope :status_inactive, -> { where(active: false) }

  validates :price, :number_of_tickets, numericality: { null: false }
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :facility_fee, :spiff, :flat_payout,
            numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :maximum_uses_per_production, :maximum_uses_per_performance,
            numericality: { greater_than_or_equal_to: 0, allow_nil: true, only_integer: true }
  validates :months_till_expiration, presence: true
  validates :name, :price, :number_of_tickets, :use_ticket_class_code, presence: true

  before_validation :set_public_sale_by_active
  validate :validate_autofulfill_configuration, if: :autofulfill?

  # Performance codes this offer automatically redeems against at purchase
  # time (see FlexPassOrder#autofulfill_ticket_orders!). Codes are upcased to
  # match Performance#clean_values normalization.
  def autofulfill_performance_code_list
    (autofulfill_performance_codes || '').split(',').map { |code| code.strip.upcase }.compact_blank
  end

  def autofulfill?
    autofulfill_performance_code_list.any?
  end

  def formatted_price
    ActionController::Base.helpers.number_to_currency(price || 0)
  end

  def formatted_facility_fee
    ActionController::Base.helpers.number_to_currency(facility_fee || 0)
  end

  def formatted_spiff
    ActionController::Base.helpers.number_to_currency(spiff || 0)
  end

  def formatted_flat_payout
    ActionController::Base.helpers.number_to_currency(flat_payout || 0)
  end

  private

  def set_public_sale_by_active
    self.active ||= on_sale_to_public?
  end

  def validate_autofulfill_configuration
    codes = autofulfill_performance_code_list

    duplicates = codes.tally.select { |_code, count| count > 1 }.keys
    if duplicates.any?
      errors.add(:autofulfill_performance_codes, "contains duplicate performance codes: #{duplicates.join(', ')}")
    end

    if maximum_uses_per_performance.nil? || maximum_uses_per_performance.zero?
      errors.add(:maximum_uses_per_performance, 'must be set (and non-zero) to autofulfill against performances')
      return
    end

    performances = validate_autofulfill_performances(codes)

    if codes.uniq.size * maximum_uses_per_performance > number_of_tickets.to_i
      errors.add(:autofulfill_performance_codes,
                 "requires #{codes.uniq.size * maximum_uses_per_performance} tickets " \
                 "(#{codes.uniq.size} performances x #{maximum_uses_per_performance} uses) " \
                 "but the pass only has #{number_of_tickets.to_i}")
    end

    validate_autofulfill_production_caps(performances)
  end

  def validate_autofulfill_performances(codes)
    codes.uniq.filter_map do |code|
      performance = Performance.find_by(performance_code: code)
      if performance.nil?
        errors.add(:autofulfill_performance_codes, "includes unknown performance code #{code}")
        next
      end
      if performance.production.has_reserved_seating?
        errors.add(:autofulfill_performance_codes,
                   "includes #{code}, which has reserved seating (only general admission performances can be autofulfilled)")
      end
      performance
    end
  end

  # Autofulfilling k performances of one production consumes
  # k * maximum_uses_per_performance against maximum_uses_per_production; if
  # that exceeds the cap, every purchase would fail its FlexPassPayment
  # validation, so reject the configuration up front.
  def validate_autofulfill_production_caps(performances)
    return if maximum_uses_per_production.nil? || maximum_uses_per_production.zero?

    performances.group_by(&:production).each do |production, production_performances|
      needed = production_performances.size * maximum_uses_per_performance
      next unless needed > maximum_uses_per_production

      errors.add(:autofulfill_performance_codes,
                 "would redeem #{needed} tickets for #{production.name}, " \
                 "exceeding the #{maximum_uses_per_production} maximum uses per production")
    end
  end
end
