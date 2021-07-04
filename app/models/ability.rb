class Ability
  include CanCan::Ability

  def initialize(user)
    alias_action :create, :new, to: :make
    alias_action :read, :make, :update, :edit, to: :cru
    alias_action :attended_dump, :daily_box_office_receipts, :fulfill_tickets, to: :box_office_reports
    alias_action :trg_dump, :production_sales_by_performance, :order_dump, to: :show_reports
    alias_action :house_management_seating, to: :house_management_reports
    alias_action :flexpass_sales, :weekly_box_office, to: :reconciliation_reports
    alias_action :membership_usage, to: :membership_reports
    alias_action :autocomplete_service_item_template_name, to: :modify_service_items

    can :read, FlexPassOffer, ["on_sale_to_public = ?", true] do |offer|
        offer.on_sale_to_public?
    end

    return if user.nil?
    # theater-specific staff

    can [:read, :update], Order, theater_id: user.theater_ids if user.is_theater_user?

    can :read, Production, ["theater_id in (?)", user.theater_ids] do |production|
        user.theater_ids.include?(production.id)
    end

    can :update_notes, Order
    can :read, FlexPassOffer, ["theater_id in (?)", user.theater_ids] do |flex_pass_offer|
        user.theater_ids.include?(flex_pass_offer.theater_id)
    end

    can [:read, :create, :update, :update_notes, :confirm, :quickview, :new_for_production], TicketOrder
    can :seat_unlimited, SeatAssignment
    can [:read, :create, :hold_existing], TicketOrder
    can :prehold, TicketOrder do |order|
        order.performance.production.season_seating?
    end
    can :auto_complete, Production
    can :autocomplete_tag, Address
    can [:seating_quickview,:auto_complete], Performance
    can :auto_complete, SpecialOffer
    can [:read,:update], Theater, id: user.theater_ids
    can :read, Production, theater_id: user.theater_ids
    can :read, FlexPassOffer, theater_id: user.theater_ids
    can [:cru, :autocomplete_address], Address
    can :exchange, TicketOrder
    can :cancel_held_during_seating, TicketOrder
    can :read, Performance
    can :read, ServiceItemTemplate
    can :view_backend_classes, TicketClassAllocation
    can [:read, :show_reports], Report
    can [:autocomplete_production_production_code,
            :autocomplete_performance_performance_code,
            :autocomplete_ticket_line_item_ticket_class_code,
            :autocomplete_special_offer_special_offer_code],
        TicketOrder

    return if user.is_theater_user?

    # below is for box office staff
    can [:read, :update], Order
    can [:cancel, :cru], FlexPassOrder
    can [:manage, :duplicate, :create, :delete], Performance
    can [:read, :create, :edit, :update, :duplicate], Production
    can :view_system_options, UserSession
    can :read, PaymentType
    can :manage, Theater
    can [:manage], DonationOrder
    can [:unclaimed, :fulfill_selected], Order
    can :swipe_card, Order
    can [:swipe_card, :confirm_credit_card,:hold,:mark_unclaimed,:resend_confirmation], TicketOrder
    can :fulfill, [Order, TicketOrder, FlexPassOrder, MembershipOrder]
    can :confirm_credit_card, [Order, TicketOrder, FlexPassOrder, MembershipOrder]
    can :cru, FlexPassOrder
    can :manage, TicketClass
    can :manage, FlexPassOffer
    can :view_email, Address
    can [:box_office_reports, :house_management_reports, :membership_reports, :reconciliation_reports], Report
    can [:create, :read, :reactivate, :cancel, :update_seating], MembershipOrder
    can [:read,:edit], MembershipOffer
    can :manage, SpecialFeature
    can :manage, SpecialOffer
    can :cru, DonationOrder
    can [:read, :cru, :mailing_cards], FileStore
    can :read, MembershipOffer
    can :read, FlexPassOffer
    can [:cancel, :reprint, :refund, :sell_past_performances, :order_anytime], [Order, TicketOrder]
    can [:split, :finalize_split], TicketOrder
    can :cru, Venue
    can :cru, ServiceItemTemplate
    can :cru, SeatMap
    can :read, :import_operations
    can :modify_service_items, Order
    can :process_orders_in_season_seating, TicketOrder

    return if user.is_box_office_user?

    # below is for admins
    can :manage, MembershipOffer
    can :destroy, SeatMap
    can :destroy, Production
    can :manage, PaymentType
    can :donation_dump, Report
    can [:refund], [Order, DonationOrder]
    can :manage_system_options, UserSession
    can [:delete], [TicketOrder, DonationOrder, FlexPassOrder, MembershipOrder]
    can :manage, User
    can :manage, MembershipOffer
    can [:membership_reports, :fulfill_donations, :mine_customer_data], Report
    can :manage, DefaultTicketClass

  end
end
