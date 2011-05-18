class OrderMailer < ActionMailer::Base

  def ticket_confirmation(order)
    @order = order
    mail(:to => order.address.email,
         :from => "\"Theater Wit Box Office\" <boxoffice@theaterwit.org>",
         :subject => "Your reservation ##{order.id} for #{order.performance.production.name} is confirmed")
  end

  def donation_thank_you(order)
    @order = order
    mail(:to => order.address.email,
         :from => "\"Jeremy Wechsler\" <jeremy@theaterwit.org>",
         :reply_to => "jeremy@theaterwit.org",
         :subject => "Thank you for your donation (you are AWESOME)!")
  end

  def flexpass_confirmation(order)
     @order = order
     mail(:to => order.address.email,
         :from => "\"Theater Wit Box Office\" <boxoffice@theaterwit.org>",
          :subject => "Your Theater Wit FlexPass")
  end

end
