class PerformanceDatatable < DatatableBase
  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      code: { source: 'Performance.performance_code'},
      date: { source: 'Performance.performance_date' },
      time: { source: 'Performance.performance_time', :searchable=>false },
      status: { source: 'Performance.status', orderable: false },
      actions: { orderable: false, searchable: false }
    }
  end

  def data
    records.map do |performance|
      {
        id: performance.decorate.id,
        date: performance.decorate.performance_date,
        time: performance.decorate.performance_time,
        code: performance.decorate.performance_code,
        status: performance.decorate.status,
        actions: performance.decorate.dt_actions(current_user),
        DT_RowID: performance.id
      }
    end
  end

  private

  def get_raw_records
    Performance.where(production: production)
  end

  def sort_records(records)
    records.order(:performance_date, :performance_time)
  end

  def production
    @production ||= options[:production]
  end

  # ==== These methods represent the basic operations to perform on records
  # and feel free to override them

  # def filter_records(records)
  # end

  # def paginate_records(records)
  # end

  # ==== Insert 'presenter'-like methods below if necessary


end
