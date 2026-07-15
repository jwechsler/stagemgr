class MembershipOfferDatatable < DatatableBase
  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      name: { source: 'MembershipOffer.name', orderable: false },
      on_sale: { source: 'MembershipOffer.on_sale', orderable: false },
      membership_type: { source: 'MembershipOffer.membership_type', orderable: false },
      status: { source: 'MembershipOffer.status', orderable: false },
      actions: { searchable: false, orderable: false }
    }
  end

  def data
    records.map do |record|
      {
        id: record.decorate.id,
        name: name_with_tags(record),
        on_sale: record.decorate.on_sale?,
        membership_type: record.membership_type,
        status: record.decorate.dt_actions,
        DT_RowID: record.id
      }
    end
  end

  private

  def name_with_tags(record)
    name_with_tag_pills(record.decorate.name, record.membership_offer_tags)
  end

  def filter_records(records)
    filter_with_tag_search(records, MembershipOfferTag, :membership_offer_tags) { super }
  end

  def get_raw_records
    scope = MembershipOffer.includes(:membership_offer_tags)
    case params[:status_scope]
    when 'active' then scope.status_active
    when 'inactive' then scope.status_inactive
    else scope
    end
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
