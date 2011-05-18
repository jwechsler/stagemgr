class OrderObserver < ActiveRecord::Observer
  observe Order
  require 'my_emma'
  
  def add_show_to_myemma(order)
    MyEmma.credentials = {
         :emma_account_id => '1402458',
         :signup_post => '1418001',
         :username => 'TheaterWitIsR3m0t3!',
         :password => 'Y730y7z4'
       }
    post_args = {:emma_member_name_first=>order.address.first_name, 
         :emma_member_name_last=>order.address.last_name,
         :emma_member_wildcard_1403237=>'Every other week',
         :emma_member_address=>order.address.line1,
         :emma_member_city=>order.address.city,
         :emma_member_state=>order.address.state,
         :emma_member_postal_code=>order.address.zipcode,
         "group[208104529]"=>1}
    grp = order.performance.production.myemma_attendee_group unless order.performance.nil?
    if !grp.blank?
      post_args["group[#{grp}]"] = 1
    end
    response = MyEmma.signup(order.address.email, post_args)
    if response.success? 
      order.address.add_to_mail_list = 2
      order.address.save!
    end
  end

  def after_save(order)

    if order.status == Order::PROCESSED && order.email_confirmation == 1 && !order.address.email.blank?
      case when order.contains_tickets?
          OrderMailer.ticket_confirmation(order).deliver
        when order.contains_flex_pass?
          OrderMailer.flexpass_confirmation(order).deliver
        when order.contains_donation?
          OrderMailer.donation_thank_you(order).deliver
      end
      if order.address.mailing_list_member?
        add_show_to_myemma(order)
      end
    end
  end
  
end