class PerformanceBroadcastReport < SimpleReport
  attr_reader :broadcast

  def initialize(broadcast)
    @broadcast = broadcast
    headers = ['Last Name', 'First Name', 'Phone', 'Email', 'Performance Code', 'Status']
    super(headers, nil)
    @data = []
  end

  def create
    # Get ALL orders for this performance
    all_orders = @broadcast.performance.orders
                          .includes(:address)
                          .order('addresses.last_name', 'addresses.first_name')

    # Get set of order IDs that will receive emails (for status check)
    recipient_order_ids = @broadcast.recipient_orders.pluck(:id).to_set

    all_orders.each do |order|
      address = order.address
      performance = @broadcast.performance

      @data << [
        address.last_name || '',
        address.first_name || '',
        address.phone || '',
        address.email || '',
        performance.performance_code || performance.id.to_s,
        recipient_order_ids.include?(order.id) ? 'Email Queued' : ''
      ]
    end

    filename = report_filename("broadcast-log-#{@broadcast.id}-#{Time.current.to_i}.csv")
    file_store = FileStore.new
    file_store.user = @broadcast.user
    file_store.worker = FileStore::REPORT
    file_store.notes = "Broadcast log: #{@broadcast.performance.performance_code} - \"#{@broadcast.subject}\""

    save_report_as_csv(filename, file_store)
    file_store
  end
end
