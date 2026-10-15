# frozen_string_literal: true

module Lgl
  # Finds the production a donation supports, so its LGL gift can carry the
  # production's LGL event.
  #
  # Donations placed before orders.production_id existed only carry the
  # production's name in `campaign` (copied from productions.name), so those
  # fall back to a name lookup, preferring the most recent production when a
  # name was reused.
  class ProductionResolver
    # 'Online' is the orders.campaign column default and means "no production".
    NO_PRODUCTION_CAMPAIGNS = ['Online'].freeze

    def self.resolve(order)
      return order.production if order.production

      name = order.campaign.to_s.strip
      return nil if name.blank? || NO_PRODUCTION_CAMPAIGNS.include?(name)

      production = find_by_name(name)
      Rails.logger.info("[LGL] order ##{order.id}: no production named #{name.inspect}; gift will carry no event") unless production
      production
    end

    # productions.name sometimes has trailing spaces.
    def self.find_by_name(name)
      Production.where('TRIM(name) = ?', name)
                .order(Arel.sql('COALESCE(opening_at, first_preview_at) DESC'), id: :desc)
                .first
    end
    private_class_method :find_by_name
  end
end
