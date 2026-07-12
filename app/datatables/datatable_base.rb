require 'forwardable'
class DatatableBase < AjaxDatatablesRails::ActiveRecord
  def initialize(params, opts = {})
    super
    @view = opts[:view_context]
    sanitize_search_values_for_latin1!
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

  def sanitize_search_values_for_latin1!
    return unless @params.respond_to?(:dig)

    @params[:search][:value] = strip_non_latin1(@params[:search][:value]) if @params.dig(:search, :value).present?

    columns = @params[:columns]
    return unless columns.respond_to?(:each)

    columns.each_value do |col|
      next unless col.respond_to?(:dig)

      val = col.dig(:search, :value)
      col[:search][:value] = strip_non_latin1(val) if val.present?
    end
  end

  def strip_non_latin1(str)
    str.encode(Encoding::ISO_8859_1, invalid: :replace, undef: :replace, replace: '')
       .force_encoding(Encoding::UTF_8)
  end
end
