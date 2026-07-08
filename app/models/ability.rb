class Ability
  include CanCan::Ability

  def initialize(user)
    alias_action :create, :new, to: :make
    alias_action :read, :make, :update, :edit, to: :cru
    # Seat map editor: whoever may create/update a seat map (:cru) may use the
    # graphical editor (page, data load, and batch save). Note: CanCan forbids
    # aliasing to a real action name like :update, so extend :cru instead.
    alias_action :editor, :editor_data, :bulk_update_seats, to: :cru
    alias_action :attended_dump, :daily_box_office_receipts, :fulfill_tickets, :donations_total, :membership_export,
                 :flex_pass_patron_report, to: :box_office_reports
    alias_action :trg_dump, :donation_dump, :production_sales_by_performance, :order_dump, :royalty_report,
                 to: :show_reports
    alias_action :house_management_seating, to: :house_management_reports
    alias_action :flexpass_sales, :weekly_box_office, to: :reconciliation_reports
    alias_action :membership_usage, to: :membership_reports
    alias_action :autocomplete_service_item_template_name, to: :modify_service_items

    can :read, FlexPassOffer, ['on_sale_to_public = ?', true] do |offer|
      offer.on_sale_to_public?
    end

    return if user.nil?

    # theater-specific staff

    can :read, [TicketOrder, DonationOrder]

    can :read, Production, ['theater_id in (?)', user.theater_ids] do |production|
      user.theater_ids.include?(production.id)
    end

    can :update_notes, Order
    can :read, FlexPassOffer, ['theater_id in (?)', user.theater_ids] do |flex_pass_offer|
      user.theater_ids.include?(flex_pass_offer.theater_id)
    end

    can %i[create update update_notes confirm quickview new_for_production], TicketOrder
    can :seat_unlimited, SeatAssignment
    can %i[create hold_existing], TicketOrder
    can :prehold, TicketOrder do |order|
      order.performance.production.season_seating?
    end
    can :auto_complete, Production
    can :autocomplete_tag, Address
    can %i[seating_quickview auto_complete], Performance
    can :auto_complete, SpecialOffer
    can %i[read update], Theater, id: user.theater_ids
    can :read, Production, theater_id: user.theater_ids
    can :read, FlexPassOffer, theater_id: user.theater_ids
    can :read, Address,
        ['addresses.id in (select orders.address_id from orders where orders.theater_id in (?))', user.theater_ids] do |address|
      !address.orders.map { |o| o.theater_id }.intersection(user.theater_ids).empty?
    end

    can %i[make update edit autocomplete_address], Address

    can :cancel_held_during_seating, TicketOrder
    can :read, Performance
    can :read, ServiceItemTemplate
    can :view_backend_classes, TicketClassAllocation
    can :read, Festival
    can %i[read show_reports], Report
    can :perform_analysis, Analysis unless user.is_box_office_user?
    can %i[autocomplete_production_production_code
           autocomplete_performance_performance_code
           autocomplete_ticket_line_item_ticket_class_code
           autocomplete_special_offer_special_offer_code],
        TicketOrder
    return if user.is_theater_user? && !user.is_resident?

    can :view_email, Address
    return if user.is_theater_user?

    # below is for box office staff
    can %i[read update], Order
    can %i[cancel cru], FlexPassOrder
    can %i[manage duplicate create delete release_held_seats email_attendees], Performance
    can :read, Address
    can %i[read create edit update duplicate send_sample_confirmation send_sample_followup], Production
    can :view_system_options, UserSession
    can :read, PaymentType
    can :manage, Theater
    can [:manage], DonationOrder

    can %i[unclaimed fulfill_selected], Order
    can :swipe_card, Order
    can %i[swipe_card confirm_credit_card hold mark_unclaimed resend_confirmation], TicketOrder
    can %i[fulfill read], [Order, TicketOrder, FlexPassOrder, MembershipOrder]
    can :confirm_credit_card, [Order, TicketOrder, FlexPassOrder, MembershipOrder]
    can :cru, FlexPassOrder
    can :manage, TicketClass
    can :manage, FlexPassOffer
    can %i[read cru], Festival
    can :view_email, Address
    can %i[box_office_reports house_management_reports membership_reports reconciliation_reports], Report
    can %i[create read reactivate cancel update_seating], MembershipOrder
    # Membership offers are administrator-managed: box office staff read them
    # and create orders only (:read granted below with the other offer reads)
    can :manage, SpecialFeature
    can :manage, SpecialOffer
    can :cru, DonationOrder
    can %i[read cru mailing_cards], FileStore
    can :read, MembershipOffer
    can :read, FlexPassOffer
    can %i[cancel reprint refund sell_past_performances order_anytime], [Order, TicketOrder]
    can :exchange, TicketOrder
    can %i[split finalize_split], TicketOrder
    can :convert_to_donation, TicketOrder
    can :cru, Venue
    can :cru, ServiceItemTemplate
    can :cru, SeatMap
    can :read, :import_operations
    can :modify_service_items, Order
    can :process_orders_in_season_seating, TicketOrder

    return if user.is_box_office_user?

    # below is for admins
    can :perform_analysis, Analysis
    can :manage, MembershipOffer
    can :manage, Festival
    can :merge_selected, Address
    can :destroy, SeatMap
    can :destroy, Production
    can :manage, PaymentType
    can [:refund], [Order, DonationOrder]
    can :manage_system_options, UserSession
    can [:delete], [TicketOrder, DonationOrder, FlexPassOrder, MembershipOrder]
    can :manage, User
    can :manage, MembershipOffer
    can %i[membership_reports fulfill_donations mine_customer_data], Report
    can :manage, DefaultTicketClass
  end
end
