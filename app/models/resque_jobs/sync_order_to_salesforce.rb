class SyncOrderToSalesforce
  extend Resque::Plugins::Retry
  @queue = :sync
  @retry_limit = 24
  @retry_delay = 3600

  def self.perform(order_id)
    Authorization::Maintenance::without_access_control do
      syncable = Order.find(address_id)
      syncable.sf_disable_sync_on_commit = true
      syncable.sync_to_salesforce!(true)
    end
  end

end

