require 'erb'

class OrderMailer < ActionMailer::Base
  @markdown_renderer = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
  helper ApplicationHelper

  layout 'order_mailer', except: %i[performance_reminder flex_pass_pending_reminder refunded_item_alert]

  def markdown_renderer
    Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
  end

  def ticket_confirmation(order, _address = nil, _action_by = nil)
    @order = order
    @markdown_renderer = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
    return unless !@order.performance.nil? && !@order.performance.suppress_notification?

    if @order.performance.production.confirmation_message.present?
      @confirmation_message = ERB.new(@order.performance.production.confirmation_message).result
    end
    mail(to: @order.address.email,
         from: '"Theater Wit Box Office" <boxoffice@theaterwit.org>',
         subject: "Your reservation ##{order.id} for #{@order.performance.production.name} is confirmed",
         tag: 'Ticket Confirmation')
  end

  def membership_confirmation(order, _address = nil, _action_by = nil)
    @order = order
    @membership = @order.membership
    mail(to: order.address.email,
         from: '"Theater Wit Box Office" <boxoffice@theaterwit.org>',
         subject: "Your #{@membership.membership_offer.name}",
         tag: 'Membership Confirmation')
  end

  def donation_thank_you(order, _address = nil, _action_by = nil)
    @order = order
    mail(to: order.address.email,
         from: '"Jeremy Wechsler" <jeremy@theaterwit.org>',
         subject: 'Thank you for your donation (you are AWESOME)!',
         tag: 'Donation Thank You') do |format|
      format.html { render layout: 'order_mailer_no_sidebar' }
    end
  end

  def flexpass_confirmation(order, _address = nil, _action_by = nil)
    @order = order
    mail(to: order.address.email,
         from: '"Theater Wit Box Office" <boxoffice@theaterwit.org>',
         subject: "Your #{@order.flex_pass.flex_pass_offer.name} [Order ##{@order.id}]",
         tag: 'Flex Pass Confirmation') do |format|
      format.html { render layout: 'order_mailer_no_sidebar' }
    end
  end

  def refunded_fulfilled_item_alert(order, email, action_by)
    @order = order
    @action_by = action_by
    mail(to: email, from: $EMAIL_ADDRESS['box_office'],
         subject: "Warning: Fulfilled order #{@order.id} refunded",
         tag: 'Alert')
  end

  def test_message(_address)
    mail(to: 'jeremy@theaterwit.org', from: '"Theater Wit Box Office" <boxoffice@theaterwit.org>',
         subject: 'Test',
         tag: 'Test Message')
  end

  def performance_reminder(order, _address = nil, _action_by = nil, testing = false)
    if testing || (!order.performance.suppress_notification? && order.performance.performance_date > Date.today + 1.day)
      @order = order
      @markdown_renderer = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
      mail(to: @order.address.email, from: '"Theater Wit Box Office" <boxoffice@theaterwit.org>',
           subject: "Don't forget you have a reservation for #{@order.performance.production.name}",
           tag: 'Ticket Reminder')
    else
      true
    end
  end

  def member_followup(order, _address = nil, _action_by = nil)
    @order = order
    @markdown_renderer = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
    unless @order.performance.nil?
      if @order.performance.production.follow_up_message.present?
        @follow_up_message = ERB.new(@order.performance.production.follow_up_message).result
      end
      if @order.performance.production.follow_up_message_2.present?
        @follow_up_message_2 = ERB.new(@order.performance.production.follow_up_message_2).result
      end
    end
    return if @order.performance.suppress_notification?

    mail(to: order.address.email, from: '"Jeremy Wechsler" <jeremy@theaterwit.org>',
         subject: "Thanks for coming to #{order.performance.production.name}",
         tag: 'Member Followup')
  end

  def flex_pass_followup(order, _address = nil, _action_by = nil)
    standard_followup(order)
  end

  def first_time_followup(order, _address = nil, _action_by = nil)
    @markdown_renderer = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
    @order = order
    @special_offer = PercentOffSpecialOffer.new
    @special_offer.create_code('1T', 6)
    @special_offer.auto_expire = Date.today + 3.months
    @special_offer.number_of_uses = 1
    @special_offer.amount = 25
    @special_offer.ticket_class_code = 'GEN'
    @special_offer.system_generated = true
    @special_offer.save!
    mail(to: order.address.email, from: '"Jeremy Wechsler" <jeremy@theaterwit.org>',
         subject: 'Thanks for coming to Theater Wit',
         tag: 'First Time Followup')
  end

  def membership_friend_pass(order, _address = nil, _action_by = nil, expiration_date = nil)
    @order = order
    @membership = order.membership
    return false if @membership.membership_offer.use_member_friend_code.blank?

    @special_offer = TicketClassSpecialOffer.new
    @special_offer.create_code('MF', 6)
    @special_offer.number_of_uses = 1
    @special_offer.auto_expire = expiration_date.nil? ? Date.today + 6.months : expiration_date
    @special_offer.max_tickets_per_order = 1
    @special_offer.system_generated = true
    @special_offer.change_ticket_class_code = @membership.membership_offer.use_member_friend_code
    @special_offer.membership_id = @membership.id
    @special_offer.save!
    mail(to: order.address.email, from: '"Jeremy Wechsler" <jeremy@theaterwit.org>',
         subject: 'Thanks for being a member',
         tag: 'Member Bring a Friend')
  end

  def standard_followup(order, _address = nil, _action_by = nil)
    @order = order
    @markdown_renderer = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
    return if order.performance.suppress_notification?

    mail(to: order.address.email, from: '"Jeremy Wechsler" <jeremy@theaterwit.org>',
         subject: 'Nice to see you again',
         tag: 'Standard Followup')
  end

  def flex_pass_pending_reminder(flex_pass_orders, _address = nil, _action_by = nil)
    return if flex_pass_orders.empty?

    @flex_pass_orders = flex_pass_orders
    mail(to: $EMAIL_ADDRESS['flex_pass_notifications'], from: '"Theater Wit Box Office" <boxoffice@theaterwit.org>',
         subject: 'Unprocessed Flex Passes',
         tag: 'Internal Notification') do |format|
      format.html { render layout: 'internal_mail' }
    end
  end

  def membership_pending_reminder(membership_orders, _address = nil, _action_by = nil)
    return if membership_orders.empty?

    @membership_orders = membership_orders
    mail(to: $EMAIL_ADDRESS['membership_notifications'], from: '"Theater Wit Box Office" <boxoffice@theaterwit.org>',
         subject: 'Unprocessed Memberships',
         tag: 'Internal Notification') do |format|
      format.html { render layout: 'internal_mail' }
    end
  end

  def custom_performance_broadcast(order, address = nil, _action_by = nil)
    @order = order
    @markdown_renderer = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)

    # Find the most recent broadcast for this performance (sent within last hour)
    @broadcast = order.performance.broadcasts
                      .where('sent_at > ?', 1.hour.ago)
                      .order(sent_at: :desc)
                      .first

    return unless @broadcast

    @body_html = @markdown_renderer.render(@broadcast.body)
    mail(to: address || @order.address.email,
         from: @broadcast.from_address,
         subject: @broadcast.subject,
         tag: 'Performance Broadcast')
  end
end
