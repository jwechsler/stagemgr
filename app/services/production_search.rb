# Shared production search backing the production picker typeahead
# (analysis, reports, imports). Mixes "group" entries (season / theater /
# theater tag) with individual productions; groups resolve to concrete
# production lists via #resolve_group.
class ProductionSearch
  # Whitelisted per-consumer scopes — the client can only name a key,
  # never define a scope.
  SCOPES = {
    'analysis' => ->(rel) { rel.where.not(status: Production::PRESALE) },
    'reports'  => ->(rel) { rel },
    'imports'  => ->(rel) { rel.where.not(status: Production::INACTIVE) }
  }.freeze

  RESULT_LIMIT = 20

  # Raises KeyError on an unknown scope key.
  def initialize(ability, scope_key)
    @base_scope = SCOPES.fetch(scope_key.to_s).call(Production.accessible_by(ability, :read))
  end

  def search(query, groups: true, exclude_id: nil)
    query = query.to_s.strip
    results = groups ? group_entries(query) : []
    results + production_entries(query, exclude_id: exclude_id)
  end

  def resolve_group(group_key)
    type, value = group_key.to_s.split(':', 2)

    productions = case type
                  when 'season'
                    ordered_scope.where(season: value.to_i)
                  when 'theater'
                    ordered_scope.where(theater_id: value.to_i)
                  when 'tag'
                    tagged_theater_ids = TheaterTag.where('LOWER(name) = ?', value.to_s.downcase)
                                                   .distinct.pluck(:theater_id)
                    ordered_scope.where(theater_id: tagged_theater_ids)
                  else
                    Production.none
                  end

    productions.map { |p| production_entry(p) }
  end

  private

  def group_entries(query)
    q = "%#{query.downcase}%"
    results = []

    matching_seasons = @base_scope.where('CAST(productions.season AS CHAR) LIKE :q', q: "%#{query}%")
                                  .distinct.pluck(:season).sort.reverse
    matching_seasons.each do |season|
      results << { group_key: "season:#{season}", label: "All shows in #{season}" }
    end

    accessible_theater_ids = @base_scope.distinct.pluck(:theater_id)
    Theater.where(id: accessible_theater_ids)
           .where('LOWER(name) LIKE :q', q: q)
           .each do |theater|
      results << { group_key: "theater:#{theater.id}", label: "All shows by #{theater.name}" }
    end

    # Dedup tags case-insensitively, preserving the first casing encountered.
    matching_tags = TheaterTag.where(theater_id: accessible_theater_ids)
                              .where('LOWER(name) LIKE :q', q: q)
                              .order(:name)
    seen_tag_keys = {}
    matching_tags.each do |tag|
      key = tag.name.to_s.downcase
      next if key.blank? || seen_tag_keys[key]

      seen_tag_keys[key] = true
      results << { group_key: "tag:#{tag.name}", label: "All shows tagged #{tag.name}" }
    end

    results
  end

  def production_entries(query, exclude_id: nil)
    scope = ordered_scope
            .where('LOWER(productions.name) LIKE :q OR CAST(productions.season AS CHAR) LIKE :q OR LOWER(productions.production_code) LIKE :q OR LOWER(theaters.name) LIKE :q',
                   q: "%#{query.downcase}%")
            .limit(RESULT_LIMIT)
    scope = scope.where.not(id: exclude_id) if exclude_id.to_i > 0

    scope.map { |p| production_entry(p) }
  end

  def ordered_scope
    @base_scope.left_outer_joins(:theater)
               .includes(:theater)
               .order(season: :desc, name: :asc)
  end

  def production_entry(production)
    {
      id: production.id,
      label: production.picker_label,
      name: production.name,
      season: production.season,
      theater: production.theater.name,
      theater_id: production.theater_id,
      status: production.status,
      closing_at: production.closing_at
    }
  end
end
