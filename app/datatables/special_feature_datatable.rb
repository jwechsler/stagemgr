class SpecialFeatureDatatable < DatatableBase
  
  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      name: { source: 'SpecialFeature.short_name' },
      description: { source: 'SpecialFeature.description' },
      status: { source: 'SpecialFeature.status' },
      actions: { searchable: false }
    }
  end

  def data
    records.map do |record|
      {
        id: record.decorate.id,
        name: record.decorate.short_name,
        description: record.decorate.description,
        status: record.decorate.status,
        actions: record.decorate.dt_actions,
        DT_RowID: record.id,
     }
    end
  end

  private

  def get_raw_records
    special_features = SpecialFeature.all
  end

  # ==== These methods represent the basic operations to perform on records
  # and feel free to override them

  # def filter_records(records)
  # end


  # def paginate_records(records)
  # end

  # ==== Insert 'presenter'-like methods below if necessary


end
