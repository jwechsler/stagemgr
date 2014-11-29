class UpdateAttendeesFromSalesforce
  @queue = :sync

  def self.perform(for_date = Date.today)
    for_date = Date.today if for_date.nil?
    begin
      Authorization.ignore_access_control(true)
      orders = HouseManagementReport.ticket_orders(for_date)
      orders.each { |o| o.address.sync_to_salesforce! }
    rescue ActiveRecord::RecordNotFound
    ensure
      Authorization.ignore_access_control(false)
    end
  end
end