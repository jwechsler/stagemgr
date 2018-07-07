class TheaterDatatable < AjaxDatatablesRails::Base
  extend Forwardable
  include ActionView::Helpers::NumberHelper

  def_delegator :@view, :link_to

  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      name: { source: 'Theater.name' },
      home: { source: 'Theater.url', :searchable=>false },
      theater_class: { source: 'Theater.theater_class' },
    }
  end

  def additional_data
    {
      actions: ''
    }
  end


  def data
    records.map do |record|
      {
        id: record.id,
        name: link_to(record.name, [:admin, record]),
        home: link_to("web",record.url),
        theater_class: record.theater_class,
        actions:
          (current_user.can?(:edit, record) ? link_to('Edit', [:edit, :admin, record], :id=>"edit_#{record.name.downcase.gsub(' ','_')}", :class=>'tiny  button') + " " : "") +
          (current_user.can?(:destroy, record) ? link_to('Destroy', [:admin, record], :confirm => 'Are you sure?', :method => :delete, :class=>'tiny alert button') : ""),
        DT_RowID: record.id,
     }
    end
  end

  def initialize(params, opts={})
    super(params, opts)
    @view = opts[:view_context]
  end

  private

  def get_raw_records
    theaters = Theater.all
    theaters = theaters.select{|t| current_user.theaters.include?(t)} if current_user.is_theater_user?
    theaters
  end

  def current_user
    @current_user ||= options[:current_user]
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
