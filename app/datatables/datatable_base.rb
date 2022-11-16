require 'forwardable'
class DatatableBase < AjaxDatatablesRails::ActiveRecord
  
  def initialize(params, opts={})
    super(params, opts)
    @view = opts[:view_context]
  end

  def current_user
    @current_user ||= options[:current_user]
  end

  def filter_by_name
    ->(column, formatted_value) {
      ::Arel::Nodes::SqlLiteral.new('full_name').matches('#{formatted_value}%').or(::Arel::Nodes::SqlLiteral.new('last_name').matches("#{formatted_value}%"))
    }
  end
  
end

