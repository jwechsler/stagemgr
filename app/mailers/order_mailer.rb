class OrderMailer < ActionMailer::Base

  layout "order_mailer", :except=>:performance_reminder

  def ticket_confirmation(order)
    @order = order
    mail(:to => @order.address.email,
         :from => "\"Theater Wit Box Office\" <boxoffice@theaterwit.org>",
         :subject => "Your reservation ##{order.id} for #{@order.performance.production.name} is confirmed",
         :tag=>"Ticket Confirmation")
  end

  def donation_thank_you(order)
    @order = order
    mail(:to => order.address.email,
         :from => "\"Jeremy Wechsler\" <jeremy@theaterwit.org>",
         :subject => "Thank you for your donation (you are AWESOME)!",
         :tag=>"Donation Thank You")
  end

  def flexpass_confirmation(order)
    @order = order
    @order.flex_pass_line_items.each { |li|
      @flex_pass_offer = li.flex_pass_offer
      @flex_passes = li.flex_passes
      mail(:to => order.address.email,
           :from => "\"Theater Wit Box Office\" <boxoffice@theaterwit.org>",
           :subject => "Your #{@flex_pass_offer.name} order",
           :tag=>"Flex Pass Confirmation")
    }
  end

  def test_message(address)
    mail(:to=>"jeremy@theaterwit.org",:from=>"\"Theater Wit Box Office\" <boxoffice@theaterwit.org>",
    :subject=>"Test",
    :tag=>"Test Message")
  end

  def performance_reminder(order)
    @order = order
    mail(:to=>@order.address.email,:from=>"\"Theater Wit Box Office\" <boxoffice@theaterwit.org>",
         :subject=>"Don't forget you have tickets to #{@order.performance.production.name}",
         :tag=>"Ticket Reminder")
  end

  def member_followup(order)
    inline_signature
    mail(:to=>order.address.email,:from=>"\"Jeremy Wechsler\" <jeremy@theaterwit.org>",
         :subject=>"Thanks for coming to #{order.performance.production.name}",
         :tag=>"Member Followup")
  end

  def flex_pass_followup(order)
    standard_followup(order)
  end

  def first_time_followup(order)
    @order = order
    @special_offer = PercentOffSpecialOffer.new
    @special_offer.create_code('1T',6)
    @special_offer.auto_expire = Date.today + 3.months
    @special_offer.number_of_uses = 1
    @special_offer.amount = 25
    @special_offer.ticket_class_code = "GEN"
    @special_offer.save!
    inline_signature
    mail(:to=>order.address.email,:from=>"\"Jeremy Wechsler\" <jeremy@theaterwit.org>",
         :subject=>"Thanks for coming to Theater Wit",
         :tag=>"First Time Followup")
  end

  def standard_followup(order)
    @order = order
    inline_signature
    mail(:to=>order.address.email,:from=>"\"Jeremy Wechsler\" <jeremy@theaterwit.org>",
         :subject=>"Nice to see you again",
         :tag=>"Standard Followup")
  end

  def inline_signature
    attachments.inline['signature.png'] = File.read("#{::Rails.root.to_s}/public/images/jmwsignature.png")
  end

end
