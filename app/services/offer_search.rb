# Shared offer search backing the offer picker typeahead on the admin
# reports page (see offer_picker.js). Mixes "group" entries (tag /
# theater restriction) with individual offers; groups resolve to concrete
# offer lists via #resolve_group. Only Active offers are ever returned.
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
      theater_groups: false
    },
    'flex_pass' => {
      model: 'FlexPassOffer',
      tag_model: 'FlexPassOfferTag',
      tag_foreign_key: :flex_pass_offer_id,
      active: ->(rel) { rel.where(active: true) },
      theater_groups: true
    }
  }.freeze

  RESULT_LIMIT = 20

  # Raises KeyError on an unknown kind key.
  def initialize(ability, kind_key)
    @kind = KINDS.fetch(kind_key.to_s)
    @model = @kind[:model].constantize
    @base_scope = @kind[:active].call(@model.accessible_by(ability, :read))
  end

  # Narrows request-supplied ids to offers the user may actually report
  # on (authorized and Active); everything else is dropped silently.
  def permitted_ids(ids)
    ids = Array(ids).map(&:to_i).select(&:positive?)
    return [] if ids.empty?

    @base_scope.where(id: ids).pluck(:id)
  end

  def search(query)
    query = query.to_s.strip
    group_entries(query) + offer_entries(query)
  end

  def resolve_group(group_key)
    type, value = group_key.to_s.split(':', 2)

    offers = case type
             when 'tag'
               ordered_scope.merge(@model.tagged_with(value))
             when 'theater'
               theater_group_scope(value.to_i)
             else
               @model.none
             end

    offers.map { |offer| offer_entry(offer) }
  end

  private

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

  def ordered_scope
    scope = @base_scope.order(:name)
    scope = scope.includes(:theater) if theater_groups?
    scope
  end

  def offer_entry(offer)
    entry = { id: offer.id, label: offer.name, name: offer.name }
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
