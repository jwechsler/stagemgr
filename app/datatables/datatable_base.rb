require 'forwardable'
class DatatableBase < AjaxDatatablesRails::ActiveRecord
  
  def initialize(params, opts={})
    super(params, opts)
    @view = opts[:view_context]
    sanitize_search_values_for_latin1!
  end

  def current_user
    @current_user ||= options[:current_user]
  end

  def filter_by_name
    ->(column, formatted_value) {
      ::Arel::Nodes::SqlLiteral.new('full_name').matches("#{formatted_value}%").or(::Arel::Nodes::SqlLiteral.new('last_name').matches("#{formatted_value}%"))
    }
  end

  private

  def sanitize_search_values_for_latin1!
    return unless @params.respond_to?(:dig)

    if @params.dig(:search, :value).present?
      @params[:search][:value] = strip_non_latin1(@params[:search][:value])
    end

    columns = @params[:columns]
    return unless columns.respond_to?(:each)

    columns.each_value do |col|
      next unless col.respond_to?(:dig)
      val = col.dig(:search, :value)
      col[:search][:value] = strip_non_latin1(val) if val.present?
    end
  end

  def strip_non_latin1(str)
    str.encode(Encoding::ISO_8859_1, invalid: :replace, undef: :replace, replace: "")
       .force_encoding(Encoding::UTF_8)
  end

end

