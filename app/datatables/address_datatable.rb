class AddressDatatable < DatatableBase

  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      id: { source: 'Address.id', searchable: false},
      full_name: { source: 'Address.full_name', cond: filter_by_name},
      email: { source: 'Address.email', cond: :start_with},
      visits: { searchable: false },
      description: { searchable: false }
    }
  end

  def data
    records.map do |record|
      {
        id: record.id,
        full_name: record.decorate.full_name,
        email: record.decorate.email,
        visits: record.decorate.visits(current_user),
        description: record.decorate.description
      }
    end
  end

  def get_raw_records
    Address.all

    # User.all
  end

  def sort_records(records)
    records.order(:last_name, :first_name)
  end

  
end
