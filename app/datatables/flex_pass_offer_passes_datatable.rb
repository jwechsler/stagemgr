# Outstanding passes of one flex pass offer (its admin show page): active,
# unexpired, with tickets left. Tickets redeemed come from the
# FlexPass.with_tickets_redeemed subquery, so rows cost no extra queries.
class FlexPassOfferPassesDatatable < DatatableBase
  def view_columns
    @view_columns ||= {
      code: { source: 'FlexPass.code' },
      patron: { source: 'Address.full_name' },
      order: { searchable: false, orderable: false },
      purchased: { source: 'FlexPass.created_at', searchable: false },
      expires: { source: 'FlexPass.expiration_date', searchable: false },
      uses_remaining: { searchable: false, orderable: false },
      fulfillment: { searchable: false, orderable: false }
    }
  end

  def data
    records.map do |pass|
      decorated = pass.decorate
      {
        code: pass.code,
        patron: decorated.patron_link,
        order: decorated.order_link,
        purchased: decorated.purchased_on,
        expires: decorated.expires_on,
        uses_remaining: flex_pass_offer.number_of_tickets.to_i - pass.tickets_redeemed.to_i,
        fulfillment: decorated.fulfillment_label,
        DT_RowId: pass.id
      }
    end
  end

  # The patron column searches and sorts on the order's address (see
  # FlexPassDecorator#patron_link). preload, not includes: includes would
  # eager-load via JOIN and drop the custom tickets_redeemed select.
  def get_raw_records
    flex_pass_offer.flex_passes.outstanding.with_tickets_redeemed
                   .left_outer_joins(flex_pass_line_item: { order: :address })
                   .preload(:address, flex_pass_line_item: { order: :address })
  end

  def flex_pass_offer
    @flex_pass_offer ||= options[:flex_pass_offer]
  end
end
