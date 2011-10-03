module Salesforce

end

class SalesforceSync
  def SalesforceSync.connect_client
    client = Databasedotcom::Client.new(:client_id => $DATABASEDOTCOM['client_id'], :client_secret=>$DATABASEDOTCOM['client_secret'])
    client.authenticate :username=>$DATABASEDOTCOM['username'], :password=>$DATABASEDOTCOM['password']
    client
  end

  def SalesforceSync.materialize_all
    client = SalesforceSync.connect_client
    client.sobject_module = Salesforce
    client.materialize(%w(Contact Account Opportunity))
  end

  def SalesforceSync.sync_addresses_to_salesforce
    addresses = Address.where("created_at > ? and sf_last_sync_at < updated_at or sf_last_sync_at is null", DateTime.now + 1.hour)
    addresses.each {|a| a.sync_to_salesforce! if a.orders.size > 0}
  end

  def SalesforceSync.sync_addresses_from_salesforce
    contacts = Salesforce::Contact.find_all_by_stagemgr_last_sync_at__c("true")
    contacts.each do |c|
      address = Address.find(c.stagemgr_id__c)
      address.sync_to_salesforce!
    end
  end

end
