class TicketClassDatatable < AjaxDatatablesRails::Base
  extend Forwardable
  include ActionView::Helpers::NumberHelper

  def_delegator :@view, :link_to
  def_delegator :@view, :number_to_currency
  def_delegator :@view, :raw

  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      class_code: { source: 'TicketClass.class_code'},
      class_name: { source: 'TicketClass.class_name'},
      ticket_price: { source: 'TicketClass.ticket_price'},
      ticketing_fee: { source: 'TicketClass.ticketing_fee', :searchable=>false},
      web_visible: { source: 'TicketClass.web_visible', :searchable=>false},
      ticket_type: { source: 'TicketClass.ticket_type'},

    }
  end

  def additional_data
    {
      actions: ''
    }
  end

  def allowed_actions(ticket_class)
    actions = []
    actions << link_to('Edit', [:edit, :admin, theater, production, ticket_class], class: 'button tiny') if current_user.can? :update, TicketClass
    actions << link_to('Destroy', [:admin, theater,production, ticket_class], :confirm => 'Are you sure?', :method => :delete, class: 'button alert tiny') if current_user.can? :destroy, TicketClass
    '<ul class="button-group">' + actions.map{|a| "<li>#{a}</li>"}.join+ '</ul>'
  end

  def checkmark(value)
    value ? raw("<span class=\"fa fa-check\" />") : ""
  end

  def make_label(value)
    "<span class=\"label info\">#{value}</span>"
  end

  def data
    records.map do |ticket_class|
      {
        id: ticket_class.id,
        class_code: ticket_class.class_code,
        class_name: ticket_class.class_name,
        ticket_price: raw("<span class=\"text-right\">#{number_to_currency ticket_class.ticket_price}</span>"),
        ticketing_fee: raw("<span class=\"text-right\">#{number_to_currency ticket_class.ticketing_fee}</span>"),
        web_visible: checkmark(ticket_class.web_visible?),
        ticket_type: raw(make_label(ticket_class.ticket_type) + (ticket_class.minutes_before_show.blank? ? "" : make_label(" #{ticket_class.minutes_before_show} minutes before"))),
        actions: raw(allowed_actions(ticket_class)),
        DT_RowID: ticket_class.id,
     }
    end
  end

  def initialize(params, opts={})
    super(params, opts)
    @view = opts[:view_context]
  end

  private

  def get_raw_records
    production.ticket_classes
  end

  def current_user
    @current_user ||= options[:current_user]
  end

  def production
    @production ||= options[:production]
  end

  def theater
    @theater ||= @production.theater
  end

  # ==== These methods represent the basic operations to perform on records
  # and feel free to override them

  # def filter_records(records)
  # end

  def sort_records(records)
    records.sort_by {|tc| tc.class_code}
  end

  # def paginate_records(records)
  # end

  # ==== Insert 'presenter'-like methods below if necessary


end
