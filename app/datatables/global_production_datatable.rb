class GlobalProductionDatatable < ProductionDatatable
  def view_columns
    @view_columns ||= {
      name: { source: 'Production.name', orderable: false },
      theater: { source: 'Theater.name', orderable: false },
      season: { source: 'Production.season', searchable: false, orderable: false },
      status: { source: 'Production.status', orderable: false },
      actions: { searchable: false, orderable: false }
    }
  end

  def data
    records.map do |record|
      {
        id: record.decorate.id,
        name: record.decorate.name,
        theater: record.decorate.theater_link,
        season: record.decorate.season,
        status: record.decorate.status,
        actions: record.decorate.dt_actions,
        DT_RowID: record.id
      }
    end
  end

  private

  def get_raw_records
    options[:accessible_scope].left_outer_joins(:theater).includes(:theater).order(opening_at: :desc)
  end
end
