class VenueDatatable < DatatableBase
  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      name: { source: 'Venue.name', cond: :like },
      actions: { serachable: false }
    }
  end

  def data
    records.map do |venue|
      {
        name: venue.decorate.name,
        actions: venue.decorate.dt_actions
        # example:
        # id: record.id,
        # name: record.name
      }
    end
  end

  private

  def get_raw_records
    Venue.all
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

  def current_user
    @current_user ||= options[:current_user]
  end
end
