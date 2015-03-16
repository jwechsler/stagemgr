
class SyncAddressToSalesforce
  extend Resque::Plugins::Retry
  @queue = :sync
  @retry_limit = 24
  @retry_delay = 3600

  def self.perform(address_id)
    begin
      Authorization.ignore_access_control(true)
      a = Address.find(address_id)
      a.sf_disable_sync_on_commit = true
      a.sync_to_salesforce!(true) if (a.orders.count > 0 || !a.sf_contact_id.blank?) && !a.sf_purge.blank?
    rescue ActiveRecord::RecordNotFound
    ensure
      Authorization.ignore_access_control(false)
    end
  end

end
