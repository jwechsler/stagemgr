class Address < ActiveRecord::Base

  validates_presence_of :last_name

  MAILLIST_STATUS = (
  REQUESTED, SAVED = 
  "Requested", "Saved" )
  
  def mailing_list_member?
    self.add_to_mail_list.blank? ? false : self.add_to_mail_list > 0
  end

  attr_accessible :first_name, :last_name, :line1, :line2, :city, :state, :zipcode, :email, :phone

end
