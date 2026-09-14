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
         from: house.box_office_from,
         subject: "Your reservation ##{order.id} for #{@order.performance.production.name} is confirmed",
         tag: 'Ticket Confirmation')
  end

  def membership_confirmation(order, _address = nil, _action_by = nil)
    @order = order
    @membership = @order.membership
    mail(to: order.address.email,
         from: house.box_office_from,
         subject: "Your #{@membership.membership_offer.name}",
         tag: 'Membership Confirmation')
  end

  def donation_thank_you(order, _address = nil, _action_by = nil)
    @order = order
    mail(to: order.address.email,
         from: house.artistic_director_from,
         subject: I18n.t('order_mailer.donation_thank_you.subject'),
         tag: 'Donation Thank You') do |format|
      format.html { render layout: 'order_mailer_no_sidebar' }
    end
  end

  def flexpass_confirmation(order, _address = nil, _action_by = nil)
    @order = order
    mail(to: order.address.email,
         from: house.box_office_from,
         subject: "Your #{@order.flex_pass.flex_pass_offer.name} [Order ##{@order.id}]",
         tag: 'Flex Pass Confirmation') do |format|
      format.html { render layout: 'order_mailer_no_sidebar' }
    end
  end

  def refunded_fulfilled_item_alert(order, email, action_by)
    @order = order
    @action_by = action_by
    mail(to: email, from: Rails.configuration.x.email_address['box_office'],
         subject: "Warning: Fulfilled order #{@order.id} refunded",
         tag: 'Alert')
  end

  def test_message(address = nil)
    # OutreachTask dispatches any mailer method with an Order, so only an
    # explicitly addressed String is treated as a recipient here.
    mail(to: (address.presence if address.is_a?(String)) || Rails.configuration.x.email_address['software_address'],
         from: house.box_office_from,
         subject: 'Test',
         tag: 'Test Message')
  end

  def performance_reminder(order, _address = nil, _action_by = nil, testing = false)
    if testing || (!order.performance.suppress_notification? && order.performance.performance_date > Date.current + 1.day)
      @order = order
      @markdown_renderer = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
      mail(to: @order.address.email, from: house.box_office_from,
           subject: "Don't forget you have a reservation for #{@order.performance.production.name}",
           tag: 'Ticket Reminder')
    else
      true
    end
  end

  def member_followup(order, _address = nil, _action_by = nil)
    @order = order
    @markdown_renderer = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
    return if @order.performance.suppress_notification?

    mail(to: order.address.email, from: house.artistic_director_from,
         subject: "Thanks for coming to #{order.performance.production.name}",
         tag: 'Member Followup')
  end

  def first_time_followup(order, _address = nil, _action_by = nil)
    @markdown_renderer = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
    @order = order
    mail(to: order.address.email,
         tag: 'First Time Followup',
         **followup_envelope(order, "Thanks for coming to #{house.name}"))
  end

  def membership_friend_pass(order, _address = nil, _action_by = nil, expiration_date = nil)
    @order = order
    @membership = order.membership
    return false if @membership.membership_offer.use_member_friend_code.blank?

    @special_offer = TicketClassSpecialOffer.new
    @special_offer.create_code('MF', 6)
    @special_offer.number_of_uses = 1
    @special_offer.auto_expire = expiration_date.nil? ? Date.current + 6.months : expiration_date
    @special_offer.max_tickets_per_order = 1
    @special_offer.system_generated = true
    @special_offer.change_ticket_class_code = @membership.membership_offer.use_member_friend_code
    @special_offer.membership_id = @membership.id
    @special_offer.save!
    mail(to: order.address.email, from: house.artistic_director_from,
         subject: 'Thanks for being a member',
         tag: 'Member Bring a Friend')
  end

  def standard_followup(order, _address = nil, _action_by = nil)
    @order = order
    @markdown_renderer = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
    return if order.performance.suppress_notification?

    mail(to: order.address.email,
         tag: 'Standard Followup',
         **followup_envelope(order, 'Nice to see you again'))
  end

  def flex_pass_pending_reminder(flex_pass_orders, _address = nil, _action_by = nil)
    return if flex_pass_orders.empty?

    @flex_pass_orders = flex_pass_orders
    mail(to: Rails.configuration.x.email_address['flex_pass_notifications'], from: house.box_office_from,
         subject: 'Unprocessed Flex Passes',
         tag: 'Internal Notification') do |format|
      format.html { render layout: 'internal_mail' }
    end
  end

  def membership_pending_reminder(membership_orders, _address = nil, _action_by = nil)
    return if membership_orders.empty?

    @membership_orders = membership_orders
    mail(to: Rails.configuration.x.email_address['membership_notifications'], from: house.box_office_from,
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

  private

  # The facts about this house -- who the box office is, who signs the mail --
  # for the envelope. One instance per delivered message: a mailer object is
  # built per call, so this is memoized for the duration of one email and picks
  # up an edited theater row on the next.
  # Views reach the same object through ApplicationHelper#theater_info.
  def house
    @house ||= TheaterInfo.new
  end

  def followup_envelope(order, producing_subject)
    if order.performance.production.theater.producing?
      { from: house.artistic_director_from, subject: producing_subject }
    else
      { from: house.box_office_from, subject: "Thanks for coming to #{order.performance.production.name}" }
    end
  end
end
