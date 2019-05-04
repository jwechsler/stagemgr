class ServiceItemTemplateDatatable < DatatableBase
  extend Forwardable
  include ActionView::Helpers::NumberHelper

  def_delegator :@view, :link_to
  def_delegator :@view, :edit_admin_service_item_template_path
  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      name: { source: 'ServiceItemTemplate.name' },
      description: { source: 'ServiceItemTemplate.description' },
      amount: { source: 'ServiceItemTemplate.amount', searchable:false },
      facility_fee: {source: 'ServiceItemTemplate.facility_fee', searchable:false }
    }
  end

  def additional_data
    {
      actions: ''
    }
  end

  def data
    records.map do |service_item_template|
      {
        id: service_item_template.id,
        name: link_to(service_item_template.name, edit_admin_service_item_template_path(service_item_template)),
        description: service_item_template.description,
        amount: service_item_template.amount,
        facility_fee: service_item_template.facility_fee,
        actions:
          (current_user.can?(:edit, service_item_template) ? link_to('Edit', [:edit, :admin, service_item_template], :id=>"edit_#{service_item_template.name.downcase}", :class=>'tiny button') + " " : "") +
          (current_user.can?(:destroy, service_item_template) ? link_to('Destroy', [:admin, service_item_template], :confirm => 'Are you sure?', :method => :delete, :class=>'tiny alert button') : ""),
        DT_RowID: service_item_template.id
     }

    end
  end

  def initialize(params, opts={})
    super(params, opts)
    @view = opts[:view_context]
  end

  private

  def get_raw_records
    ServiceItemTemplate.all
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
