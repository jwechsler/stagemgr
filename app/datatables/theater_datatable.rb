class TheaterDatatable < DatatableBase

  include ActionView::Helpers::NumberHelper

  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      name: { source: 'Theater.name' },
      home: { source: 'Theater.url', :searchable=>false },
      theater_class: { source: 'Theater.theater_class' },
      actions: { searchable: false, sortable: false}
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
        name: record.decorate.name,
        home: record.decorate.url,
        theater_class: record.decorate.theater_class,
        actions: record.decorate.dt_actions(current_user),
        _RowID: record.id,
     }
    end
  end

  private

  def get_raw_records
    if current_user.is_theater_user?
      Theater.where(id: current_user.theater_ids)
    else
      Theater.all
    end
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
