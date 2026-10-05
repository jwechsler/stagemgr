# Shared offer search backing the offer picker typeahead on the admin
# reports page (see offer_picker.js). Mixes "group" entries (tag /
# theater restriction) with individual offers; groups resolve to concrete
# offer lists via #resolve_group. Only Active offers are returned unless
# the caller passes include_inactive: true; aggregates: true adds the
# whole-catalogue groups (see #aggregate_entries).
class OfferSearch
  # Whitelisted per-kind configuration — the client can only name a key,
  # never define a scope. Membership offers carry no theater restriction,
  # so theater groups apply to flex pass offers only.
  KINDS = {
    'membership' => {
      model: 'MembershipOffer',
      tag_model: 'MembershipOfferTag',
      tag_foreign_key: :membership_offer_id,
      active: ->(rel) { rel.where(status: MembershipOffer::ACTIVE) },
      active_first: "membership_offers.status = '#{MembershipOffer::ACTIVE}' DESC",
      noun: 'membership offers',
      theater_groups: false,
      # Groups the caller expands when it runs, not when picked: the picker
      # keeps them as a single row (see MembershipAnalysis.offer_ids_for_groups).
      dynamic_groups: { MembershipAnalysis::WITH_ACTIVE_MEMBERSHIPS => 'Offers with active memberships in the selected dates' }
    },
    'flex_pass' => {
      model: 'FlexPassOffer',
      tag_model: 'FlexPassOfferTag',
      tag_foreign_key: :flex_pass_offer_id,
      active: ->(rel) { rel.where(active: true) },
      active_first: 'flex_pass_offers.active DESC',
      noun: 'flex pass offers',
      theater_groups: true,
      dynamic_groups: {}
    }
  }.freeze

  RESULT_LIMIT = 20
  AGGREGATE_ALL = 'all'.freeze
  AGGREGATE_ACTIVE = 'active'.freeze
  # Typed words that bring up each aggregate shortcut (see #aggregate_entries).
  AGGREGATE_KEYWORDS = { AGGREGATE_ALL => %w[all], AGGREGATE_ACTIVE => %w[all active] }.freeze
  DYNAMIC_GROUP_KEYWORDS = %w[active].freeze

  # Raises KeyError on an unknown kind key. include_inactive: true widens
  # every lookup to inactive offers too (the Membership Analysis picker,
  # which reports on retired offers); their labels then say "(Inactive)".
  def initialize(ability, kind_key, include_inactive: false, aggregates: false)
    @kind = KINDS.fetch(kind_key.to_s)
    @model = @kind[:model].constantize
    @include_inactive = include_inactive
    @aggregates = aggregates
    accessible = @model.accessible_by(ability, :read)
    @base_scope = include_inactive ? accessible : @kind[:active].call(accessible)
  end

  # Narrows request-supplied ids to offers the user may actually report
  # on (authorized, and Active unless include_inactive); everything else is
  # dropped silently.
  def permitted_ids(ids)
    ids = Array(ids).map(&:to_i).select(&:positive?)
    return [] if ids.empty?

    @base_scope.where(id: ids).pluck(:id)
  end

  def search(query)
    query = query.to_s.strip
    aggregate_entries(query) + group_entries(query) + offer_entries(query)
  end

  # Label of a dynamic group key, or nil when the key is not one.
  def self.dynamic_group_label(kind_key, group_key)
    KINDS.fetch(kind_key.to_s)[:dynamic_groups][group_key.to_s]
  end

  def resolve_group(group_key)
    type, value = group_key.to_s.split(':', 2)

    offers = case type
             when 'tag'
               ordered_scope.merge(@model.tagged_with(value))
             when 'theater'
               theater_group_scope(value.to_i)
             when AGGREGATE_ALL
               @aggregates ? ordered_scope : @model.none
             when AGGREGATE_ACTIVE
               @aggregates ? @kind[:active].call(ordered_scope) : @model.none
             else
               @model.none
             end

    offers.map { |offer| offer_entry(offer) }
  end

  private

  # Whole-catalogue shortcuts, offered when the query starts one of their
  # keywords ("all", "active"). Matching keywords rather than the whole label
  # keeps them out of ordinary name searches: "wit" must not match "with".
  # "All" and "active" resolve to concrete offers like any group; dynamic
  # groups carry dynamic: true and never resolve here.
  def aggregate_entries(query)
    term = query.downcase
    return [] unless @aggregates && term.present?

    entries = [{ group_key: AGGREGATE_ALL, label: "All #{@kind[:noun]}" },
               { group_key: AGGREGATE_ACTIVE, label: "All active #{@kind[:noun]}" }]
    entries += @kind[:dynamic_groups].map { |key, label| { group_key: key, label: label, dynamic: true } }
    entries.select do |entry|
      keywords = AGGREGATE_KEYWORDS.fetch(entry[:group_key], DYNAMIC_GROUP_KEYWORDS)
      keywords.any? { |keyword| keyword.start_with?(term) }
    end
  end

  def theater_groups?
    @kind[:theater_groups]
  end

  def tag_model
    @kind[:tag_model].constantize
  end

  def group_entries(query)
    q = "%#{query.downcase}%"
    results = tag_group_entries(q)
    results += theater_group_entries(q) if theater_groups?
    results
  end

  # Dedup tags case-insensitively, preserving the first casing encountered
  # (same convention as ProductionSearch).
  def tag_group_entries(pattern)
    matching_tags = tag_model.where(@kind[:tag_foreign_key] => @base_scope.select(:id))
                             .where('LOWER(name) LIKE ?', pattern)
                             .order(:name)
    seen = {}
    matching_tags.filter_map do |tag|
      key = tag.name.to_s.downcase
      next if key.blank? || seen[key]

      seen[key] = true
      { group_key: "tag:#{tag.name}", label: "All offers tagged #{tag.name}" }
    end
  end

  # Theaters that have at least one Active offer restricted to them; a
  # theater group deliberately excludes exclude_theater offers ("all but
  # this theater") — those stay findable by name or tag.
  def theater_group_entries(pattern)
    restricted_theater_ids = @base_scope.where(exclude_theater: false)
                                        .where.not(theater_id: nil)
                                        .distinct.pluck(:theater_id)
    Theater.where(id: restricted_theater_ids)
           .where('LOWER(name) LIKE ?', pattern)
           .order(:name)
           .map { |theater| { group_key: "theater:#{theater.id}", label: "All #{theater.name} offers" } }
  end

  def theater_group_scope(theater_id)
    return @model.none unless theater_groups?

    ordered_scope.where(theater_id: theater_id, exclude_theater: false)
  end

  def offer_entries(query)
    q = "%#{query.downcase}%"
    scope = ordered_scope
    scope = if theater_groups?
              scope.left_outer_joins(:theater)
                   .where("LOWER(#{@model.table_name}.name) LIKE :q OR LOWER(theaters.name) LIKE :q", q: q)
            else
              scope.where("LOWER(#{@model.table_name}.name) LIKE ?", q)
            end
    scope.limit(RESULT_LIMIT).map { |offer| offer_entry(offer) }
  end

  # Inactive offers (include_inactive only) sort after every active one.
  def ordered_scope
    scope = @include_inactive ? @base_scope.order(Arel.sql(@kind[:active_first])) : @base_scope
    scope = scope.order(:name)
    scope = scope.includes(:theater) if theater_groups?
    scope
  end

  def offer_entry(offer)
    entry = { id: offer.id, label: offer.name, name: offer.name }
    if @include_inactive
      entry[:active] = offer.active?
      entry[:label] = "#{offer.name} (Inactive)" unless offer.active?
    end
    if theater_groups?
      entry[:label] = [offer.name, restriction_text(offer)].compact.join(' — ')
      entry[:restriction] = restriction_text(offer)
      entry[:theater_id] = offer.theater_id
    end
    entry
  end

  # Mirrors FlexPassOfferDecorator#restriction_text wording.
  def restriction_text(offer)
    return nil if offer.theater.blank?

    offer.exclude_theater ? "All but #{offer.theater.name}" : "Only #{offer.theater.name}"
  end
end
