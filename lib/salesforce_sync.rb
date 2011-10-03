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
    addresses.each { |a| a.sync_to_salesforce! if a.orders.size > 0 }
  end

  def SalesforceSync.sync_addresses_from_salesforce
    contacts = Salesforce::Contact.find_all_by_stagemgr_last_sync_at__c("true")
    contacts.each do |c|
      address = Address.find(c.stagemgr_id__c)
      address.sync_to_salesforce!
    end
  end

  def SalesforceSync.merge_purge_addresses(delete_sf_records = false)

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
          address.delete
        end
        if !address.sf_last_sync_at.nil? && delete_sf_records
          sf_contact = Salesforce::Contact.find_by_stagemgr_id__c(a.id.to_s)
          sf_contact.delete unless sf_contact.nil?
        end

      end
    end
    nil
  end
end
