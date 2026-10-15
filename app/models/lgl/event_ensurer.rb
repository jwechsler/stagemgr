# frozen_string_literal: true

module Lgl
  # Finds or creates the LGL event standing for one Production, stores its id
  # in productions.lgl_event_id, and keeps it reconciled: active and dated from
  # the production's run. The gift campaign is set on a new event, or on one
  # whose campaign is blank; an event already on another campaign keeps it,
  # since gifts posted to it keep theirs. Events made by hand in LGL
  # (campaign_id and end_date often blank) are adopted by exact name and patched.
  #
  # Returns the event id, or nil when the read-only guard skipped the create
  # (nothing is stored).
  class EventEnsurer
    COMPARED_KEYS = %i[campaign_id date end_date is_active].freeze

    def initialize(client, campaign_id:, for_address_id:)
      @client = client
      @campaign_id = campaign_id
      @for_address_id = for_address_id
    end

    def ensure_for(production)
      wanted = desired(production)
      linked = linked_event(production)
      return reconcile(linked, wanted) if linked

      found = find_by_name(wanted[:name], production.season)
      if found
        production.update_column(:lgl_event_id, Integer(found['id']))
        Rails.logger.info("[LGL] production ##{production.id}: adopted event #{found['id']}")
        return reconcile(found, wanted)
      end

      create(production, wanted)
    end

    private

    attr_reader :client, :campaign_id, :for_address_id

    def desired(production)
      attrs = { name: production.name.to_s.strip, campaign_id: campaign_id, is_active: true }
      return attrs unless dated?(production)

      attrs.merge(date: production.first_performance_at.to_date.iso8601,
                  end_date: production.effective_closing_at&.to_date&.iso8601)
    end

    # first_performance_at falls back to a far-future sentinel when none of
    # these is set, so check them directly.
    def dated?(production)
      [production.first_preview_at, production.press_opening_at, production.opening_at].any?(&:present?)
    end

    # The stored event, or nil (after clearing the stale id) when LGL 404s.
    def linked_event(production)
      return nil if production.lgl_event_id.blank?

      event = client.find_event(production.lgl_event_id)
      production.update_column(:lgl_event_id, nil) if event.nil?
      event
    end

    def find_by_name(name, season)
      wanted = name.downcase
      matches = client.search_events(name).select { |event| event['name'].to_s.strip.downcase == wanted }
      return matches.first if matches.size <= 1

      in_season = matches.select { |event| event['date'].to_s[0, 4] == season.to_s }
      (in_season.presence || matches).max_by { |event| Integer(event['id']) }
    end

    def create(production, wanted)
      created = client.create_event(wanted, for_address_id: for_address_id)
      if created.nil?
        Rails.logger.info("[LGL] production ##{production.id}: event create skipped (read-only)")
        return nil
      end

      id = Integer(created['id'])
      production.update_column(:lgl_event_id, id)
      Rails.logger.info("[LGL] production ##{production.id}: created event #{id}")
      id
    end

    def reconcile(event, wanted)
      id = Integer(event['id'])
      patch = wanted_for(event, wanted)
      client.update_event(id, patch, for_address_id: for_address_id) if drifted?(event, patch)
      id
    end

    # Never overwrite a campaign the event already has.
    def wanted_for(event, wanted)
      event['campaign_id'].present? ? wanted.except(:campaign_id) : wanted
    end

    def drifted?(event, wanted)
      COMPARED_KEYS.any? do |key|
        next false unless wanted.key?(key)

        key == :is_active ? event['is_active'] != true : event[key.to_s].to_s != wanted[key].to_s
      end
    end
  end
end
