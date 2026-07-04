class SeatMapDatatable < DatatableBase
  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      label: { source: 'SeatMap.label' },
      base_image_map: { source: 'SeatMap.base_image_map', searchable: false },
      actions: { searchable: false }
      # id: { source: "User.id", cond: :eq },
      # name: { source: "User.name", cond: :like }
    }
  end

  def data
    records.map do |record|
      {
        label: record.decorate.label,
        base_image_map: record.decorate.base_image_map(SeatMap::THUMB),
        actions: record.decorate.dt_actions
        # example:
        # id: record.id,
        # name: record.name
      }
    end
  end

  private

  def get_raw_records
    venue.seat_maps
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

  def venue
    @venue ||= options[:venue]
  end

  def root_url
    @root_url ||= options[:root_url]
  end
end
