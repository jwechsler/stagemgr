module Salesforce

end

class SalesforceSync

  def SalesforceSync.materialize_all
    client = Databasedotcom::Client.new(:client_id => $DATABASEDOTCOM['client_id'], :client_secret=>$DATABASEDOTCOM['client_secret'])
    client.authenticate :username=>$DATABASEDOTCOM['username'], :password=>$DATABASEDOTCOM['password']
    client.sobject_module = Salesforce
    client.materialize(%w(Contact Account Opportunity))
  end

end
