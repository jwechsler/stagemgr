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
    %w(Contact Account Opportunity User RecordType Product2).each { |c| client.materialize(c) unless Salesforce.const_defined?(c)}
    client
  end

  def SalesforceSync.sync_addresses_to_salesforce
    client = SalesforceSync.materialize_all
    addresses = Address.where("created_at > ? and sf_last_sync_at < updated_at or sf_last_sync_at is null", DateTime.now + 1.hour)
    addresses.each { |a| a.sync_to_salesforce! if a.orders.size > 0 }
  end

  def SalesforceSync.sync_addresses_from_salesforce
    SalesforceSync.materialize_all
    contacts = Salesforce::Contact.find_all_by_stagemgr_last_sync_at__c("true")
    contacts.each do |c|
      address = Address.find(c.stagemgr_id__c)
      address.sync_to_salesforce!
    end
  end

  def SalesforceSync.sync_productions
    client = SalesforceSync.materialize_all

    prods = Production.where("sf_last_sync_at is null or sf_last_sync_at < updated_at")
    record_type = Salesforce::RecordType.find_by_Name("Production")
    prods.each{ |p| p.sync_to_salesforce!(nil, record_type) }
  end

  def SalesforceSync.sync_orders
    client = SalesforceSync.materialize_all
    user = Salesforce::User.find_by_Username(client.username)
    record_type = Salesforce::RecordType.find_by_Name('Donation')


    orders = DonationOrder.where("sf_last_sync_at is null or sf_last_sync_at < updated_at")
    orders.select{|o| o.total > 0}.each do |order|
      order.sync_to_salesforce!(user,record_type)
    end
  end

  def SalesforceSync.merge_purge_addresses(delete_sf_records = false)
    SalesforceSync.materialize_all if delete_sf_records
    addresses = Address.all
    addresses.each do |address|
      merge = address.find_original
      unless merge.nil?
        puts "Merging related records for #{address.id} into #{merge.id}"
        Address.transaction do
          orders = Order.find_all_by_address_id(address.id)
          orders.each { |order|
            puts "  Transferring order ##{order.id}"
            order.address_id = merge.id
            order.save!
          }
          tags = AddressTag.find_all_by_address_id(address.id)
          tags.each { |tag|
            puts "  Transferring tag ##{tag.id}"

            tag.address_id = merge.id
            tag.save!
          }
          memberships = Membership.find_all_by_address_id(address.id)
          memberships.each { |membership|
            puts "  Transferring membership ##{membership.id}"

            membership.address_id = merge.id
            membership.save!
          }
          flex_passes = FlexPass.find_all_by_address_id(address.id)
          flex_passes.each { | flex_pass |
            puts "  Transferring flexpass ##{flex_pass.id}"

            flex_pass.address_id = merge.id
            flex_pass.save!
          }
          merge.update_from(address)
          merge.save!

        end
        if !address.sf_last_sync_at.nil? && delete_sf_records
          sf_contact = Salesforce::Contact.find_by_stagemgr_id__c(address.id.to_s)
          sf_contact.delete unless sf_contact.nil?
        end
        address.delete unless merge.nil?
      end
    end
    nil
  end
end
