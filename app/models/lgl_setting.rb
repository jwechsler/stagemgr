# frozen_string_literal: true

# Account-level Little Green Light facts chosen in the app rather than in
# config: the campaign gifts are written to, the moment gift replication went
# live, and the appeal id standing for each season. One row per key.
class LglSetting < ApplicationRecord
  CAMPAIGN_ID = 'campaign_id'
  CAMPAIGN_NAME = 'campaign_name'
  GIFTS_SINCE = 'gifts_since'
  SEASON_APPEAL_PREFIX = 'season_appeal_id:'

  Campaign = Struct.new(:id, :name)

  validates :key, presence: true, uniqueness: true

  def self.fetch(key)
    find_by(key: key)&.value
  end

  def self.store(key, value)
    find_or_initialize_by(key: key).tap { |setting| setting.update!(value: value.to_s) }
  end

  def self.campaign
    id = fetch(CAMPAIGN_ID)
    return nil if id.blank?

    Campaign.new(Integer(id), fetch(CAMPAIGN_NAME))
  end

  # The first campaign choice stamps GIFTS_SINCE, the go-live moment:
  # donations created before it are never replicated. Later changes keep it.
  def self.store_campaign(id, name)
    transaction do
      store(CAMPAIGN_ID, id)
      store(CAMPAIGN_NAME, name)
      store(GIFTS_SINCE, Time.current.iso8601) if fetch(GIFTS_SINCE).blank?
    end
  end

  def self.gifts_since
    value = fetch(GIFTS_SINCE)
    value.blank? ? nil : Time.zone.parse(value)
  end

  def self.season_appeal_id(season)
    value = fetch("#{SEASON_APPEAL_PREFIX}#{season}")
    value.blank? ? nil : Integer(value)
  end

  def self.store_season_appeal_id(season, id)
    store("#{SEASON_APPEAL_PREFIX}#{season}", id)
  end
end
