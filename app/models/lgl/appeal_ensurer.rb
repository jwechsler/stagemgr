# frozen_string_literal: true

module Lgl
  # Finds or creates the LGL appeal standing for one season ("2026 Ticketing")
  # under the chosen campaign, and remembers its id in LglSetting so later
  # gifts for the season need no lookup.
  #
  # An existing appeal with the exact name is adopted, given the campaign only
  # when it has none, and re-activated. An appeal already on another campaign
  # keeps it: gifts posted to it keep theirs, so the appeal must too. Returns
  # the appeal id, or nil when the read-only guard skipped the create (nothing
  # is remembered).
  class AppealEnsurer
    NAME_SUFFIX = ' Ticketing'
    APPEAL_TYPE_NAME = 'Ticketing'
    CODE_SUFFIX = 'TICKETING'

    def initialize(client, campaign_id:, for_address_id:)
      @client = client
      @campaign_id = campaign_id
      @for_address_id = for_address_id
    end

    def ensure_for_season(season)
      cached = LglSetting.season_appeal_id(season)
      return cached if cached

      name = "#{season}#{NAME_SUFFIX}"
      existing = find_by_name(name)
      return adopt(season, name, existing) if existing

      create(season, name)
    end

    private

    attr_reader :client, :campaign_id, :for_address_id

    def find_by_name(name)
      wanted = name.strip.downcase
      matches = client.search_appeals(name).select { |appeal| appeal['name'].to_s.strip.downcase == wanted }
      matches.min_by { |appeal| Integer(appeal['id']) }
    end

    def adopt(season, name, appeal)
      id = Integer(appeal['id'])
      needs_campaign = appeal['campaign_id'].blank? && campaign_id.present?
      if needs_campaign || appeal['is_active'] == false
        body = { name: name, is_active: true }
        body[:campaign_id] = campaign_id if needs_campaign
        client.update_appeal(id, body, for_address_id: for_address_id)
      end
      LglSetting.store_season_appeal_id(season, id)
      Rails.logger.info("[LGL] season #{season}: adopted appeal #{id}")
      id
    end

    def create(season, name)
      created = client.create_appeal({ name: name, campaign_id: campaign_id, appeal_type_name: APPEAL_TYPE_NAME,
                                       code: code_for(season), is_active: true },
                                     for_address_id: for_address_id)
      if created.nil?
        Rails.logger.info("[LGL] season #{season}: appeal create skipped (read-only)")
        return nil
      end

      id = Integer(created['id'])
      LglSetting.store_season_appeal_id(season, id)
      Rails.logger.info("[LGL] season #{season}: created appeal #{id}")
      id
    end

    def code_for(season)
      "#{format('%<year>02d', year: season.to_i % 100)}#{CODE_SUFFIX}"
    end
  end
end
