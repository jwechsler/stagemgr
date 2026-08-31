# Materializes a ResourcedTicketClass as one shadow TicketClass per production
# in its venues, and keeps those rows attribute-synced with the resource.
#
# It creates NO allocations of its own: saving a shadow TicketClass fires
# TicketClass#sync_allocations_async, which enqueues SyncTicketClassAllocationsJob
# for that class. That job is the single owner of allocation creation and
# auto_attach handling, and it already limits itself to sellable performances on
# or after today.
class SyncResourcedTicketClassJob < ApplicationJob
  include LoggedJob

  @queue = :sync

  def self.perform(resourced_ticket_class_id)
    resource = ResourcedTicketClass.find_by(id: resourced_ticket_class_id)
    return if resource.nil?

    sync_shadow_classes(resource)
    decommission_out_of_scope_shadow_classes(resource)
  end

  # Productions that still matter: anything with a performance today or later,
  # plus productions that have no performances yet (they are being built, and
  # Performance#populate_ticket_class_allocations will pick the shadow row up as
  # soon as one is added). Closed productions are deliberately skipped -- a
  # shadow row there could never produce an allocation, and syncing every
  # historical production in a venue would churn hundreds of inert rows.
  def self.productions_in_scope(resource)
    Production.where(venue_id: resource.venue_ids)
              .where('EXISTS (SELECT 1 FROM performances WHERE performances.production_id = productions.id ' \
                     'AND performances.performance_date >= :today) ' \
                     'OR NOT EXISTS (SELECT 1 FROM performances WHERE performances.production_id = productions.id)',
                     today: Date.current)
  end

  def self.sync_shadow_classes(resource)
    productions_in_scope(resource).find_each do |production|
      sync_one(resource, production)
    end
  end

  def self.sync_one(resource, production)
    tc = TicketClass.find_or_initialize_by(production_id: production.id,
                                           resourced_ticket_class_id: resource.id)
    tc.synced_from_resource = true
    tc.attributes = resource.shadow_attributes
    tc.save!
  rescue ActiveRecord::RecordInvalid => e
    # Most often a class_code collision with a manual class on this production
    # (the legacy ASSIST class). We never adopt an existing row automatically --
    # that would rewrite its price and hand its sales history to the resource.
    # Log it and keep going; the remaining productions must still sync.
    Rails.logger.warn(
      "SyncResourcedTicketClassJob: could not sync '#{resource.class_code}' onto " \
      "production #{production.production_code} (#{production.id}) - #{e.message}"
    )
  end

  # Shadow rows whose production has moved out of the resource's venue set (the
  # venue was removed from the resource, or the production was moved). History is
  # never deleted: the class is withdrawn from sale and its future allocations
  # are switched off.
  def self.decommission_out_of_scope_shadow_classes(resource)
    stale = TicketClass.joins(:production)
                       .where(resourced_ticket_class_id: resource.id)
                       .where.not(productions: { venue_id: resource.venue_ids })
    ResourcedTicketClass.decommission_shadow_classes(stale)
  end
end
