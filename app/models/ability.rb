class Ability
  include CanCan::Ability

  def initialize(user)
    alias_action :create, :new, to: :make
    alias_action :read, :create, :update, :edit, to: :cru
    alias_action :attended_dump, :daily_box_office_receipts, :fulfill_tickets, to: :box_office_reports
    alias_action :trg_dump, :production_sales_by_performance, :order_dump, to: :show_reports
    alias_action :house_management_seating, to: :house_management_reports
    alias_action :flexpass_sales, :weekly_box_office, to: :reconciliation_reports
    alias_action :membership_usage, to: :membership_reports


    return if user.nil?
    # theater-specific staff
    can :read, Order
    can [:read, :create, :update, :update_notes], TicketOrder
    can [:read, :create, :hold_existing], TicketOrder
    can :auto_complete, Production
    can :auto_complete, Performance
    can :auto_complete, SpecialOffer
    can [:read,:update], Theater, id: user.theater_ids
    can :read, Production, theater_id: user.theater_ids
    can :read, FlexPassOffer, theater_id: user.theater_ids
    can [:cru, :autocomplete_address], Address
    can :exchange, TicketOrder
    can :read, Performance
    can [:read, :show_reports], Report
    can [:autocomplete_production_production_code,
            :autocomplete_performance_performance_code,
            :autocomplete_ticket_line_item_ticket_class_code,
            :autocomplete_special_offer_special_offer_code],
        TicketOrder

    return if user.is_theater_user?

    # below is for box office staff
    can :cru, FlexPassOrder
    can [:manage, :duplicate, :create], Performance
    can [:manage, :duplicate], Production
    can :view_system_options
    can :read, PaymentType
    can :manage, Theater
    can [:manage, :fulfill], DonationOrder
    can [:swipe_card, :confirm_credit_card,:hold,:mark_unclaimed,:fulfill,:resend_confirmation], TicketOrder
    can :resend_confirmation, [TicketOrder]
    can :cru, FlexPassOrder
    can :manage, TicketClass
    can :manage, FlexPassOffer
    can :view_email, Address
    can [:box_office_reports, :house_management_reports, :membership_reports, :reconciliation_reports], Report
    can [:create, :read, :reactivate, :cancel], MembershipOrder
    can [:read,:edit], MembershipOffer
    can :manage, SpecialFeature
    can :manage, SpecialOffer
    can :cru, DonationOrder
    can [:read, :cru, :mailing_cards], FileStore
    can :read, MembershipOffer
    can :read, FlexPassOffer
    can :manage, SpecialOffer
    can [:cancel, :reprint, :refund, :sell_past_performances, :order_anytime], [Order, TicketOrder]

    return if user.is_box_office_user?

    # below is for admins
    can :delete, Theater
    can :delete, Production
    can :manage, MembershipOffer
    can :manage, PaymentType
    can [:refund], [Order, DonationOrder]
    can :manage_system_options
    can [:delete], [TicketOrder, DonationOrder, FlexPassOrder, MembershipOrder]
    can :manage, User
    can :manage, MembershipOffer
    can [:membership_reports, :fulfill_donations, :mine_customer_data], Report
    can :manage, DefaultTicketClass

  end
end
