require 'forwardable'
class DatatableBase < AjaxDatatablesRails::ActiveRecord
  def initialize(params, opts = {})
    super
    @view = opts[:view_context]
  end

  def current_user
    @current_user ||= options[:current_user]
  end

  def filter_by_name
    lambda { |_column, formatted_value|
      ::Arel::Nodes::SqlLiteral.new('full_name').matches("#{formatted_value}%").or(::Arel::Nodes::SqlLiteral.new('last_name').matches("#{formatted_value}%"))
    }
  end

  private

  # Renders a record name followed by its tag pills, escaping the name.
  def name_with_tag_pills(name, tags)
    pills = @view.render(
      partial: 'admin/tags/pills',
      formats: [:html],
      locals: { tags: tags.to_a }
    )
    @view.safe_join([name.to_s, pills])
  end

  # Widens the standard column search to also match a tag table's name.
  # Falls back to the caller's block (usually `super`) when there is no term.
  def filter_with_tag_search(records, tag_class, association)
    term = datatable.search.value.to_s
    return yield if term.blank?

    base = build_conditions
    tag_match = tag_class.arel_table[:name].matches("%#{term}%")
    combined = base ? base.or(tag_match) : tag_match

    records.left_outer_joins(association).where(combined).distinct
  end
end
