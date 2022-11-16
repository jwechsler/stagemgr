class FlexPassOfferDatatable < DatatableBase
  
  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      offer: { source: 'FlexPassOffer.name', cond: :like },
      price: { source: 'FlexPassOffer.price', searchable: false},
      qty:  { source: 'FlexPassOffer.number_of_tickets', searchable: false},
      public: {searchable: false, orderable: false},
      restrictions: {searchable: false, orderable: false},
      actions: {searchable: false, orderable: false}
    }
  end

  def data
    (records || []).map do |flex_pass_offer|
      {
        offer: flex_pass_offer.decorate.name,
        price: flex_pass_offer.decorate.price,
        qty: flex_pass_offer.decorate.number_of_tickets,
        public: flex_pass_offer.decorate.on_sale_to_public?,
        restrictions: flex_pass_offer.decorate.restrictions,
        actions: flex_pass_offer.decorate.dt_actions,
        DT_RowID: flex_pass_offer.id
      }
    end
  end

  private


  def get_raw_records
    FlexPassOffer.accessible_by(current_user.ability,:read)
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
