class FlexPassOfferDatatable < DatatableBase
  include ActionView::Helpers::NumberHelper

  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      offer: { source: 'FlexPassOffer.name', cond: :like },
      price: { source: 'FlexPassOffer.price', searchable: false},
      qty:  { source: 'FlexPassOffer.number_of_tickets', searchable: false},
    }
  end

  def additional_data
    {
      public: '',
      restrictions: '',
      actions: ''
    }
  end

  def data
    records.map do |flex_pass_offer|
      {
        offer: link_to(flex_pass_offer.name, [:admin, flex_pass_offer]),
        price: number_to_currency(flex_pass_offer.price),
        qty: flex_pass_offer.number_of_tickets,
        public: flex_pass_offer.on_sale_to_public? ? '√' : raw('&nbsp;'),
        restrictions: flex_pass_restrictions(flex_pass_offer),
        actions: raw(allowed_actions(flex_pass_offer)),
        # example:
        # id: record.id,
        # name: record.name
        DT_RowID: flex_pass_offer.id
      }
    end
  end

  private

  def allowed_actions(flex_pass_offer)
    actions = []
    if current_user.can? :update, FlexPassOffer then
      actions << link_to('Edit', [:edit,:admin,flex_pass_offer], :class=>'tiny button')
    end

    if current_user.can? :destroy, FlexPassOffer then
      actions <<  link_to('Destroy', [:admin, flex_pass_offer], method: :delete, :confirm=>'Are you sure?', :class=>'tiny alert button')
    end

    if current_user.can? :create, FlexPassOrder then
      if flex_pass_offer.active?
        actions << link_to('Create Order', [:new, :admin, flex_pass_offer, :order], :class=>'tiny button')
      else
        actions << link_to('Create Order', '#', :class=> 'tiny button disabled')
      end
    end

    actions.join(' ')
  end

  def get_raw_records
    FlexPassOffer.accessible_by(current_user.ability,:read)
  end

  def flex_pass_restrictions(flex_pass_offer)
    unless flex_pass_offer.theater.blank? then
      if flex_pass_offer.exclude_theater then
          "All but #{flex_pass_offer.theater.name}"
      else
          "Only #{flex_pass_offer.theater.name}"
      end
    else
      ""
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
