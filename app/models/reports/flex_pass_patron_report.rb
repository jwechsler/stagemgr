class FlexPassPatronReport < Report
  attr_reader :starting_date, :ending_date, :flex_pass_offer_ids

  # flex_pass_offer_ids accepts a single id or an array of ids; empty
  # means no offer restriction.
  def initialize(starting_date, ending_date, flex_pass_offer_ids = nil, reporting_user_id = nil)
    super(%i[flex_pass_order_number patron_name email phone flex_pass_code
             expiration_date admissions_remaining fulfilled], reporting_user_id)
    @starting_date = starting_date.is_a?(String) ? Date.parse(starting_date) : starting_date
    @ending_date = ending_date.is_a?(String) ? Date.parse(ending_date) : ending_date
    @flex_pass_offer_ids = Array(flex_pass_offer_ids).compact
    @data = []
  end

  def create
    # One row per flex pass (legacy line items carry several passes, each
    # with its own code); iterating orders and reading order.flex_pass used
    # to repeat the first pass and drop the rest.
    flex_passes = FlexPass.joins(flex_pass_line_item: { flex_pass_order: :address })
                          .includes(:flex_pass_offer, flex_pass_line_item: { flex_pass_order: :address })
                          .where(orders: { created_at: starting_date.beginning_of_day..ending_date.end_of_day })
                          .order('orders.created_at')
    flex_passes = flex_passes.where(flex_pass_offer_id: flex_pass_offer_ids) if flex_pass_offer_ids.present?

    flex_passes.each do |flex_pass|
      order = flex_pass.flex_pass_line_item.flex_pass_order
      address = order.address

      # Check if the FlexPass order has been fulfilled (processed)
      fulfilled = order.status == Order::PROCESSED ? 'Y' : 'N'

      # Format phone number
      phone = address.phone.presence || ''

      @data << {
        flex_pass_order_number: order.id,
        patron_name: address.full_name,
        email: address.email,
        phone: phone,
        flex_pass_code: flex_pass.code,
        expiration_date: flex_pass.expiration_date&.strftime('%m/%d/%Y') || 'N/A',
        admissions_remaining: flex_pass.uses_remaining,
        fulfilled: fulfilled
      }
    end

    filename = "flex_pass_patron_report_#{@starting_date.strftime('%Y%m%d')}_#{@ending_date.strftime('%Y%m%d')}.csv"
    report_data(filename)
  end
end
