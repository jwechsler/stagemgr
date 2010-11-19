class Address < ActiveRecord::Base
  MAILLIST_STATUS = (
  REQUESTED, SAVED = 
  "Requested", "Saved" )
  
  def mailing_list_member?
    self.add_to_mail_list.blank? ? false : self.add_to_mail_list > 0
  end
  
end
