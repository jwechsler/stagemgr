# frozen_string_literal: true

module Lgl
  # Refreshes one address's LGL Lapsed tag from its constituent's gifts in LGL.
  # The single entry point for anything that keeps the tag current.
  #
  # Returns :unlinked (no LGL ID; nothing read), :gone (LGL answered 404 for the
  # constituent; the tag is left as it was), or :set / :cleared / :unchanged.
  #
  # +client+ defaults to Lgl.client, built only once the address is known to be
  # linked, so an unlinked address never needs LGL configured.
  class GiftHistoryRefresh
    def self.refresh(address, client: nil, today: Date.current)
      lgl_id = address.lgl_id
      return :unlinked if lgl_id.blank?

      gifts = (client || Lgl.client).gifts(lgl_id)
      return :gone if gifts.nil?

      lapsed = GiftHistory.classify(gifts, today: today)
      return :unchanged unless address.apply_lgl_lapsed!(lapsed)

      Rails.logger.info("[LGL] address ##{address.id}: lapsed=#{lapsed || 'none'}")
      lapsed ? :set : :cleared
    end
  end
end
