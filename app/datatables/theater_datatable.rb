class TheaterDatatable < DatatableBase
  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      name: { source: 'Theater.name' },
      home: { source: 'Theater.url', searchable: false },
      theater_class: { source: 'Theater.theater_class' },
      actions: { searchable: false, orderable: false }
    }
  end

  def data
    records.map do |record|
      {
        id: record.decorate.id,
        name: name_with_tags(record),
        home: record.decorate.url,
        theater_class: record.decorate.theater_class,
        actions: record.decorate.dt_actions,
        _RowID: record.id
      }
    end
  end

  private

  def name_with_tags(record)
    pills = @view.render(
      partial: 'admin/theater_tags/pills',
      formats: [:html],
      locals: { theater_tags: record.theater_tags.to_a }
    )
    (record.decorate.name.to_s + pills.to_s).html_safe
  end

  def filter_records(records)
    term = datatable.search.value.to_s
    return super if term.blank?

    base = build_conditions
    tag_match = TheaterTag.arel_table[:name].matches("%#{term}%")
    combined = base ? base.or(tag_match) : tag_match

    records.left_outer_joins(:theater_tags).where(combined).distinct
  end

  def get_raw_records
    result = if current_user.is_theater_user?
               Theater.where(id: current_user.theater_ids)
             else
               Theater.all
             end
    result = result.includes(:theater_tags)
    result.order(Arel.sql("CASE WHEN status='#{Theater::ACTIVE}' THEN 0 WHEN status='#{Theater::INACTIVE}' THEN 1 END"),
                 Arel.sql("CASE WHEN theater_class='#{Theater::DEFAULT}' THEN 0 WHEN theater_class = '#{Theater::COPRO}' THEN 2 ELSE 3 END"),
                 :name)
  end

  # ==== These methods represent the basic operations to perform on records
  # and feel free to override them

  # def filter_records(records)
  # end

  # def paginate_records(records)
  # end

  # ==== Insert 'presenter'-like methods below if necessary
end
