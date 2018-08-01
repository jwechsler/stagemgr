class PerformanceDatatable < AjaxDatatablesRails::Base
  extend Forwardable
  include ActionView::Helpers::NumberHelper

  def_delegator :@view, :link_to
  def_delegator :@view, :raw

  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      code: { source: 'Performance.performance_code'},
      date: { source: 'Performance.performance_date' },
      time: { source: 'Performance.performance_time.to_s(:hour_min)', :searchable=>false },
      status: { source: 'Performance.status' },

    }
  end

  def additional_data
    {
      actions: ''
    }
  end

  def allowed_actions(performance)
    actions = []
    if current_user.can? :delete, Performance then
      actions << link_to('Destroy', [:admin, performance.production.theater, performance.production, performance], :confirm => 'Are you sure?', :method => :delete, class: 'tiny alert button')
    end
    if current_user.can? :update, Performance then
      actions << link_to('Edit', [:edit,:admin, production.theater, production, performance], :id=>"edit_#{performance.performance_code.gsub(' ','_')}", class: 'tiny button')
    end
    if current_user.can? :create, Performance then
      actions << link_to('Duplicate', [:duplicate, :admin, production.theater, production, performance], :id=>"duplicate_#{performance.performance_code.gsub(' ','_')}", class: 'tiny button' )
    end

    actions.join(' ')
  end

  def data
    records.map do |performance|
      {
        id: performance.id,
        date: performance.performance_date,
        time: performance.performance_time.to_s(:hour_min),
        code: link_to(performance.performance_code, [:admin, production.theater, production, performance]),
        status: raw("<span class=\"label\">#{performance.status}</span>"),
        actions: raw(allowed_actions(performance)),
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
    production.performances
  end

  def sort_records(records)
    records.sort_by{|perf1,perf2| perf1.performance_code <=> perf2.performance_code}
  end

  def current_user
    @current_user ||= options[:current_user]
  end


  def address
    @address ||= options[:production]
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
