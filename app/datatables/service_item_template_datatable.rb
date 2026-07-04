class ServiceItemTemplateDatatable < DatatableBase
  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      name: { source: 'ServiceItemTemplate.name' },
      description: { source: 'ServiceItemTemplate.description' },
      amount: { source: 'ServiceItemTemplate.amount', searchable: false },
      facility_fee: { source: 'ServiceItemTemplate.facility_fee', searchable: false },
      actions: { searchable: false }
    }
  end

  def data
    records.map do |service_item_template|
      {
        id: service_item_template.decorate.id,
        name: service_item_template.decorate.name,
        description: service_item_template.decorate.description,
        amount: service_item_template.decorate.amount,
        facility_fee: service_item_template.decorate.facility_fee,
        actions: service_item_template.decorate.dt_actions,
        DT_RowID: service_item_template.id
      }
    end
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
