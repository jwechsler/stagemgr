class ProductionDatatable < DatatableBase
  
  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      name: { source: 'Production.name' },
      season: { source: 'Production.season', :searchable=>false },
      status: { source: 'Production.status' },
      actions: { searchable: false, orderable: false}
    }
  end

  def data
    records.map do |record|
      {
        id: record.decorate.id,
        name: record.decorate.name,
        season: record.decorate.season,
        status: record.decorate.status,
        actions: record.decorate.dt_actions,
        DT_RowID: record.id
     }
    end
  end

  private

  def get_raw_records
    current_theater.productions
  end

  def current_theater
    @current_theater  ||= options[:current_theater]
  end

  # ==== These methods represent the basic operations to perform on records
  # and feel free to override them

  #def filter_records(records)
  #end

  def sort_records(records)
    records.order(opening_at: :desc)
  end

  # def paginate_records(records)
  # end

  # ==== Insert 'presenter'-like methods below if necessary

end
