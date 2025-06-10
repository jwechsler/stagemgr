class FlexPassPatronReport < Report

  attr_reader :starting_date, :ending_date

  def initialize(starting_date, ending_date, reporting_user_id = nil)
    super([:flex_pass_order_number, :patron_name, :email, :phone, :flex_pass_code, 
           :expiration_date, :admissions_remaining, :fulfilled], reporting_user_id)
    @starting_date = starting_date.is_a?(String) ? Date.parse(starting_date) : starting_date
    @ending_date = ending_date.is_a?(String) ? Date.parse(ending_date) : ending_date
    @data = Array.new
  end

  def create
    # Get FlexPassOrders within the date range
    flex_pass_orders = FlexPassOrder.joins(:flex_pass_line_item => :flex_pass)
                                   .joins(:address)
                                   .includes({:flex_pass_line_item => {:flex_pass => :flex_pass_offer}}, :address)
                                   .where('orders.created_at >= ? AND orders.created_at <= ?', 
                                          starting_date.beginning_of_day, ending_date.end_of_day)
                                   .order(:created_at)

    flex_pass_orders.each do |order|
      flex_pass = order.flex_pass
      address = order.address
      
      # Check if the FlexPass order has been fulfilled (processed)
      fulfilled = order.status == Order::PROCESSED ? 'Y' : 'N'
      
      # Format phone number
      phone = address.phone.present? ? address.phone : ''
      
      @data << {
        flex_pass_order_number: order.id,
        patron_name: address.full_name,
        email: address.email,
        phone: phone,
        flex_pass_code: flex_pass.code,
        expiration_date: flex_pass.expiration_date.strftime('%m/%d/%Y'),
        admissions_remaining: flex_pass.uses_remaining,
        fulfilled: fulfilled
      }
    end

    filename = "flex_pass_patron_report_#{@starting_date.strftime('%Y%m%d')}_#{@ending_date.strftime('%Y%m%d')}.csv"
    return self.report_data(filename)
  end

end