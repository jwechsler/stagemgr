authorization do

  role :guest do
    has_permission_on :theaters, :to=>:read
    has_permission_on :productions, :to=>:read
    has_permission_on :performances, :to=>:read
    has_permission_on :flex_pass_offers, :to=>:read
    has_permission_on :orders, :to=>[:create,:read,:update,:delete]
    has_permission_on :donation_orders, :to=>[:create,:read,:update]
    has_permission_on :flex_pass_orders, :to=>[:create,:read,:update]
    has_permission_on :ticket_orders, :to=>[:create,:read,:update,:delete]
    has_permission_on :membership_orders, :to=>[:create, :read, :update,:delete]
  end

  role :theater_user do
    has_permission_on :flex_pass_orders, :to=>[:create,:read,:update]
    has_permission_on :admin_ticket_classes, :to=>[:view]
    has_permission_on :admin_theaters, :to=>[:view]
    has_permission_on :theaters, :to=>:read
    has_permission_on :admin_orders , :to=>[:view,:manage,:make,:hold_existing]
    has_permission_on :admin_ticket_orders , :to=>[:view,:manage,:make]
    has_permission_on :admin_auto_complete, :to=>[:view]
    has_permission_on :orders, :to=>[:create, :update]
    has_permission_on :donation_orders, :to=>[:create, :update]
    has_permission_on :ticket_orders, :to=>[:create, :update]
    has_permission_on :theaters, :to=>:update do
      if_attribute :id => is_in {user.theater_ids}
    end
    has_permission_on :productions, :to=>:read do
      if_attribute :theater_id => is_in {user.theater_ids}
    end
    has_permission_on :performances, :to=>:read
    has_permission_on :admin_flex_pass_offers, :to=>:view
    has_permission_on :flex_pass_offers, :to=>:read do
      if_attribute :theater_id => is_in {user.theater_ids}
    end
    has_permission_on :admin_addresses, :to=>[:view,:manage,:make]
    has_permission_on :membership_orders, :to=>[:create, :read, :update]
    has_permission_on :admin_exchange_ticket_orders, :to=>[:make]
    has_permission_on :admin_reports, :to=>[:index]
  end

  role :box_office do
    includes :theater_user
    has_permission_on :system_options, :to=>[:view]
    has_permission_on :admin_payment_types, :to=>[:view]
    has_permission_on :admin_theaters, :to=>[:manage]
    has_permission_on :theaters, :to=>[:create,:update,:read,:manage]
    has_permission_on :donation_orders, :to=>[:create,:read,:update]
    has_permission_on :admin_orders, :to=>[:hold,:unclaimed, :fulfill, :resend_confirmation, :view_full_history]
    has_permission_on :admin_ticket_orders, :to=>[:hold,:unclaimed, :fulfill, :resend_confirmation]
    has_permission_on :admin_flex_pass_orders, :to=>[:view, :make, :manage]
    has_permission_on :productions, :to=>[:view, :make, :manage]
    has_permission_on :performances, :to=>[:view, :make, :manage, :delete]
    has_permission_on :admin_ticket_classes, :to=>[:make,:manage]
    has_permission_on :admin_flex_pass_offers, :to=>[:make, :manage, :view]
    has_permission_on :admin_addresses, :to=>[:view_email]
    has_permission_on :admin_reports, :to=>[:box_office_reports, :house_management_reports]
    has_permission_on :admin_membership_orders, :to=>[:view, :make, :manage]
    has_permission_on :admin_membership_offers, :to=>[:view]
    has_permission_on :admin_special_features, :to=>[:view,:manage]
    has_permission_on :admin_donation_orders, :to=>[:view,:manage,:make]
    has_permission_on :admin_imports, :to=>[:view, :make]
  end

  role :admin do
    includes :box_office
    has_permission_on :theaters, :to=>[:delete,:make]
    has_permission_on :admin_payment_types, :to=>[:manage, :make]
    has_permission_on :system_options, :to=>[:manage]
    has_permission_on :admin_theaters, :to=>[:make]
    has_permission_on :admin_orders, :to=>[:cancel]
    has_permission_on :orders, :to=>[:delete]
    has_permission_on :ticket_orders, :to=>[:delete]
    has_permission_on :admin_donation_orders, :to=>[:view,:manage,:make,:fulfill,:refund]
    has_permission_on :admin_ticket_orders, :to=>[:reprint]
    has_permission_on :admin_refund_orders, :to=>[:make]
    has_permission_on :admin_users, :to=>[:view, :manage, :delete, :make]
    has_permission_on :productions, :to=>:delete
    has_permission_on :admin_membership_offers, :to=>[:make, :manage, :delete]
    has_permission_on :admin_reports, :to=>[:reconciliation_reports, :membership_reports, :fulfill_donations, :mine_customer_data]
    has_permission_on :admin_default_ticket_classes, :to=>[:view, :make, :manage]
  end
end

privileges do
  privilege :make, :includes => [:create, :new]
  privilege :view, :includes => [:index, :show, :read]
  privilege :manage, :includes => [:edit, :update, :update_notes]
  privilege :box_office_reports, :includes=> [:trg_dump]
end