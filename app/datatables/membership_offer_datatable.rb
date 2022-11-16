class MembershipOfferDatatable < DatatableBase
  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      name: { source: 'MembershipOffer.name' },
      on_sale: { source: 'MembershipOffer.on_sale' },
      status: { source: 'MembershipOffer.status' },
      actions: { searchable: false, orderable: false}
    }
  end


  def data
    records.map do |record|
      {
        id: record.decorate.id,
        name: record.decorate.name,
        on_sale: record.decorate.on_sale?,
        status: record.decorate.dt_actions,
        DT_RowID: record.id,
     }
    end
  end

  private

  def get_raw_records
    MembershipOffer.all
    # insert query here
  end

  def sort_records(records)
    records.order(Arel.sql("case when status='#{MembershipOffer::ACTIVE}' then 1 else 2 end, on_sale desc, name"))
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
