module SalesforceData

  class SalesForceIntegrityException < Exception
  end

end

class SalesforceSync
  def SalesforceSync.connect_client(client_id=nil, client_secret=nil, username=nil, password=nil, host=nil)
    client_id = $DATABASEDOTCOM['client_id'] if client_id.nil?
    client_secret = $DATABASEDOTCOM['client_secret'] if client_secret.nil?
    username = $DATABASEDOTCOM['username'] if username.nil?
    password = $DATABASEDOTCOM['password'] + $DATABASEDOTCOM['token'] if password.nil?
    host = $DATABASEDOTCOM['host'] if host.nil?
    client = Databasedotcom::Client.new(:client_id => client_id, :client_secret=>client_secret, :host=>host)
    client.authenticate :username=>username, :password=>password
    client
  end

  def SalesforceSync.materialize_all(client_id = nil, client_secret = nil, username = nil, password = nil, host = nil)
    client = SalesforceSync.connect_client(client_id, client_secret, username, password, host)
    client.sobject_module = ::SalesforceData
    %w(Contact Account Opportunity User RecordType Product2 Event OrderActivity__c).each { |c| client.materialize(c) }
    client
  end

  def SalesforceSync.load_from_yaml_file(environment, yaml_file)

    databasedotcom_config = YAML::load(File.open(yaml_file))
    salesforcesync = databasedotcom_config[environment]
    if salesforcesync['sync_to_salesforce']
      begin
        client = SalesforceSync.materialize_all(salesforcesync['client_id'],
                                                salesforcesync['client_secret'],
                                                salesforcesync['username'],
                                                salesforcesync['password']+salesforcesync['token'],
						salesforcesync['host'])
	user = SalesforceData::User.find_by_Username(client.username)
        salesforcesync['user_id'] = user.Id
        donation_record_type = SalesforceData::RecordType.find_by_Name('Donation')
        salesforcesync['donation_record_type_id'] = donation_record_type.Id
        production_record_type = SalesforceData::RecordType.find_by_Name("Production")
        salesforcesync['production_record_type_id'] = production_record_type.Id
        ticket_order_type = SalesforceData::RecordType.find_by_Name("Ticket Order")
        salesforcesync['ticket_order_record_type_id'] = ticket_order_type.Id
      rescue => e
#        puts e.message
#	puts e.backtrace
        salesforcesync['sync_to_salesforce'] = "false"
      end
    end
    salesforcesync
  end

  def SalesforceSync.sync_addresses_to_salesforce
    client = SalesforceSync.materialize_all
    addresses = Address.where("created_at > ? and sf_last_sync_at < updated_at or sf_last_sync_at is null", DateTime.now + 1.hour)
    addresses.each { |a| a.sync_to_salesforce! if a.orders.size > 0 }
  end

  def SalesforceSync.sync_addresses_from_salesforce
    SalesforceSync.materialize_all
    contacts = SalesforceData::Contact.find_all_by_stagemgr_last_sync_at__c("true")
    contacts.each do |c|
      address = Address.find(c.stagemgr_id__c)
      address.sync_to_salesforce!
    end
  end

  def SalesforceSync.sync_productions
    prods = Production.where("sf_last_sync_at is null or sf_last_sync_at < updated_at")
    record_type = SalesforceData::RecordType.find_by_Name("Production")
    prods.each { |p| p.sync_to_salesforce! }
  end

  def SalesforceSync.sync_orders
    donation_record_type_id = SalesforceData::RecordType.find_by_Name('Donation').Id
    sf_cache = SyncCache.new
    orders = DonationOrder.where("sf_last_sync_at is null or sf_last_sync_at < updated_at")
    orders.select { |o| o.total > 0 }.each do |order|
      order.sync_to_salesforce!($DATABASEDOTCOM['user_id'], $DATABASEDOTCOM['donation_record_type_id'])
    end
    orders = TicketOrder.where("sf_last_sync_at is null or sf_last_sync_at < updated_at and status in (?)",
     Order.syncable_statuses).order("created_at desc").limit(2250)
    o_id = 0
    Authorization.ignore_access_control(true)
    begin
      orders.each do |o|
        o_id = o.id
        o.sync_to_salesforce!(sf_cache)
      end
    rescue => e
      puts "Sync of ticket order #{o_id} failed, #{e}"
      puts e.backtrace
    end
    Authorization.ignore_access_control(false)
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
          flex_passes.each { |flex_pass|
            puts "  Transferring flexpass ##{flex_pass.id}"

            flex_pass.address_id = merge.id
            flex_pass.save!
          }
          merge.update_from(address)
          merge.save!

        end
        if !address.sf_last_sync_at.nil? && delete_sf_records
          sf_contact = SalesforceData::Contact.find_by_stagemgr_id__c(address.id.to_s)
          sf_contact.delete unless sf_contact.nil?
        end
        address.delete unless merge.nil?
      end
    end
    nil
  end
end
