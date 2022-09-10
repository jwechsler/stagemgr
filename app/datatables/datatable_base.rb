require 'forwardable'
class DatatableBase < AjaxDatatablesRails::ActiveRecord
  extend Forwardable
  
  def_delegator :@view, :raw
  def_delegator :@view, :link_to

  def initialize(params, opts={})
    super(params, opts)
    @view = opts[:view_context]
  end

  def current_user
    @current_user ||= options[:current_user]
  end

end

