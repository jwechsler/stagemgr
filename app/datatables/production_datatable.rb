class ProductionDatatable < AjaxDatatablesRails::Base
  extend Forwardable
  include ActionView::Helpers::NumberHelper

  def_delegator :@view, :link_to
  def_delegator :@view, :raw

  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      name: { source: 'Production.name' },
      season: { source: 'Production.season', :searchable=>false },
      status: { source: 'Production.status' },
    }
  end

  def additional_data
    {
      actions: ''
    }
  end

  def allowed_actions(production)
    actions = []
    if current_user.can? :destroy, Production then
      actions <<  link_to('Destroy', [:admin, production.theater, production], :confirm=>'Are you sure?', :method=>:delete, :class=>'alert tiny button')
    end
    if current_user.can? :edit, Production then
      actions << link_to('Edit', [:edit, :admin, production.theater, production], :class=> "tiny button")
    end
    if current_user.can? :read, TicketClass then
      actions << link_to('Ticket Classes', [:admin, production.theater, production, :ticket_classes], class: 'tiny button')
    end
    actions.join(' ')
  end

  def data
    records.map do |production|
      {
        id: production.id,
        name: link_to(production.name, [:admin, production.theater, production]) +
          (production.custom_label.blank? ? "" : "<br/><span class=\"label\">#{production.custom_label.titlecase}</span>"),
        season: production.season,
        status: raw("<span class=\"label\">#{production.status}</span>"),
        actions: raw(allowed_actions(production)),
        DT_RowID: production.id
     }
    end
  end

  def initialize(params, opts={})
    super(params, opts)
    @view = opts[:view_context]
  end

  private

  def get_raw_records
    current_theater.productions
  end

  def current_user
    @current_user ||= options[:current_user]
  end

  def current_theater
    @current_theater  ||= options[:current_theater]
  end

  # ==== These methods represent the basic operations to perform on records
  # and feel free to override them

  # def filter_records(records)
  # end

  # def sort_records(records)
  # end

  # def paginate_records(records)
  # end

  # ==== Insert 'presenter'-like methods below if necessary


end
