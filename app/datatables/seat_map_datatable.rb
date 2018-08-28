class SeatMapDatatable < DatatableBase

  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      label: { source: "SeatMap.label"},
      base_image_map: { source: "SeatMap.base_image_map", :searchable=>false},
      # id: { source: "User.id", cond: :eq },
      # name: { source: "User.name", cond: :like }
    }
  end

  def data
    records.map do |record|
      {
        label: link_to(record.label,[:admin, venue, record]),
        base_image_map: raw("<img src=\"#{record.base_image_map.url(:thumb)}\" />"),
        actions: raw(allowed_actions(record))
        # example:
        # id: record.id,
        # name: record.name
      }
    end
  end

  def additional_data
    {
      actions: ''
    }
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

  def allowed_actions(seat_map)
    actions = []
    actions << link_to("Edit", [:edit,:admin, venue, seat_map], class: 'tiny button') if current_user.can?(:edit, SeatMap)
    actions << ("<li>" +link_to('Destroy', [:admin, venue, seat_map], :confirm => 'Are you sure?', :method => :delete, :class=>'tiny alert button') + "</li>") if current_user.can?(:destroy, SeatMap)
    "<ul class=\"button-group\"><li>#{actions.join('</li><li>')}</li></ul>"
  end

end
