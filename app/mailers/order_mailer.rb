require "erb"

class OrderMailer < ActionMailer::Base
  @markdown_renderer = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
  helper ApplicationHelper

  layout "order_mailer", :except=>[:performance_reminder, :flex_pass_pending_reminder, :refunded_item_alert]

  def markdown_renderer
    Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
  end

  def ticket_confirmation(order,address=nil,action_by=nil)
    @order = order
    @markdown_renderer = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
     if !@order.performance.nil?
      @confirmation_message = ERB.new(@order.performance.production.confirmation_message).result if !@order.performance.production.confirmation_message.blank?
    end
    mail(:to => @order.address.email,
         :from => "\"Theater Wit Box Office\" <boxoffice@theaterwit.org>",
         :subject => "Your reservation ##{order.id} for #{@order.performance.production.name} is confirmed",
         :tag=>"Ticket Confirmation")
  end

  def membership_confirmation(order,address=nil,action_by=nil)
    @order = order
    @membership = @order.membership
    mail(:to => order.address.email,
         :from => "\"Theater Wit Box Office\" <boxoffice@theaterwit.org>",
         :subject => "Your #{@membership.membership_offer.name}",
         :tag=>"Membership Confirmation")
  end

  def donation_thank_you(order,address=nil,action_by=nil)
    @order = order
    mail(:to => order.address.email,
         :from => "\"Jeremy Wechsler\" <jeremy@theaterwit.org>",
         :subject => "Thank you for your donation (you are AWESOME)!",
         :tag=>"Donation Thank You")
  end

  def flexpass_confirmation(order,address=nil,action_by=nil)
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

  def refunded_fulfilled_item_alert(order, email, action_by)
    @order = order
    @action_by = action_by
    mail(:to=> email, :from => $EMAIL_ADDRESS['box_office'],
         :subject=>"Warning: Fulfilled order #{@order.id} refunded",
         :tag=>"Alert")
  end

  def test_message(address)
    mail(:to=>"jeremy@theaterwit.org", :from=>"\"Theater Wit Box Office\" <boxoffice@theaterwit.org>",
         :subject=>"Test",
         :tag=>"Test Message")
  end

  def performance_reminder(order,address=nil,action_by=nil)
    if order.performance.performance_date > Date.today+1.day
      @order = order
      @markdown_renderer = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
      mail(:to=>@order.address.email, :from=>"\"Theater Wit Box Office\" <boxoffice@theaterwit.org>",
           :subject=>"Don't forget you have a reservation for #{@order.performance.production.name}",
           :tag=>"Ticket Reminder")
    else
      true
    end
  end

  def member_followup(order,address=nil,action_by=nil)
    @order = order
    @markdown_renderer = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
    if !@order.performance.nil?
      @follow_up_message = ERB.new(@order.performance.production.follow_up_message).result if !@order.performance.production.follow_up_message.blank?
      @follow_up_message_2 = ERB.new(@order.performance.production.follow_up_message).result if !@order.performance.production.follow_up_message_2.blank?
    end
    mail(:to=>order.address.email, :from=>"\"Jeremy Wechsler\" <jeremy@theaterwit.org>",
         :subject=>"Thanks for coming to #{order.performance.production.name}",
         :tag=>"Member Followup")
  end

  def flex_pass_followup(order,address=nil,action_by=nil)
    standard_followup(order)
  end

  def first_time_followup(order,address=nil,action_by=nil)
    @markdown_renderer = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
    @order = order
    @special_offer = PercentOffSpecialOffer.new
    @special_offer.create_code('1T', 6)
    @special_offer.auto_expire = Date.today + 3.months
    @special_offer.number_of_uses = 1
    @special_offer.amount = 25
    @special_offer.ticket_class_code = "GEN"
    @special_offer.system_generated = true
    @special_offer.save!
    mail(:to=>order.address.email, :from=>"\"Jeremy Wechsler\" <jeremy@theaterwit.org>",
         :subject=>"Thanks for coming to Theater Wit",
         :tag=>"First Time Followup")
  end

  def membership_friend_pass(order,address=nil,action_by=nil,expiration_date=nil)
    @order = order
    @membership = order.membership
    @special_offer = TicketClassSpecialOffer.new
    @special_offer.create_code("MF",6)
    @special_offer.number_of_uses = 1
    @special_offer.auto_expire = expiration_date.nil? ? Date.today + 6.months : expiration_date
    @special_offer.max_tickets_per_order = 1
    @special_offer.system_generated = true
    @special_offer.change_ticket_class_code = @membership.membership_offer.use_member_friend_code
    @special_offer.membership_id = @membership.id
    @special_offer.save!
    mail(:to=>order.address.email, :from=>"\"Jeremy Wechsler\" <jeremy@theaterwit.org>",
         :subject=>"Thanks for being a member",
         :tag=>"Member Bring a Friend")
  end

  def standard_followup(order,address=nil,action_by=nil)
    @order = order
    @markdown_renderer = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
    mail(:to=>order.address.email, :from=>"\"Jeremy Wechsler\" <jeremy@theaterwit.org>",
         :subject=>"Nice to see you again",
         :tag=>"Standard Followup")
  end

  def flex_pass_pending_reminder(flex_pass_orders,address=nil,action_by=nil)
    unless flex_pass_orders.empty?
      @flex_pass_orders = flex_pass_orders
      mail(:to=>$EMAIL_ADDRESS['flex_pass_notifications'], :from=>"\"Theater Wit Box Office\" <boxoffice@theaterwit.org>",
           :subject=>"Unprocessed Flex Passes",
           :tag=>"Internal Notification") do |format|
        format.html { render layout: 'internal_mail'}
      end
    end
  end

  def membership_pending_reminder(membership_orders,address=nil,action_by=nil)
    unless membership_orders.empty?
      @membership_orders = membership_orders
      mail(:to=>$EMAIL_ADDRESS['membership_notifications'], :from=>"\"Theater Wit Box Office\" <boxoffice@theaterwit.org>",
           :subject=>"Unprocessed Mmeberships",
           :tag=>"Internal Notification") do |format|
        format.html { render layout: 'internal_mail'}
      end
    end
  end

end
