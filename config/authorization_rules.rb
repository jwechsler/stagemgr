authorization do

  role :guest do
    has_permission_on :theaters, :to=>:read
    has_permission_on :productions, :to=>:read
    has_permission_on :performances, :to=>:read
    has_permission_on :flex_pass_offers, :to=>:read
    has_permission_on :orders, :to=>[:create,:read,:update,:delete]
    has_permission_on :ticket_orders, :to=>[:create,:read,:update,:delete]
    has_permission_on :membership_orders, :to=>[:create, :read, :update,:delete]
  end

  role :theater_user do
    has_permission_on :admin_ticket_classes, :to=>[:view]
    has_permission_on :admin_theaters, :to=>[:view]
    has_permission_on :theaters, :to=>:read
    has_permission_on :admin_orders , :to=>[:view,:manage,:make,:hold_existing]
    has_permission_on :admin_ticket_orders , :to=>[:view,:manage,:make]
    has_permission_on :admin_auto_complete, :to=>[:view]
    has_permission_on :orders, :to=>[:create, :update]
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
  end

  role :box_office do
    includes :theater_user
    has_permission_on :admin_theaters, :to=>[:manage]
    has_permission_on :theaters, :to=>[:create,:update,:read]

    has_permission_on :admin_orders, :to=>[:hold,:unclaimed, :fulfill]
    has_permission_on :admin_ticket_orders, :to=>[:hold,:unclaimed, :fulfill]
    has_permission_on :productions, :to=>[:view, :make, :manage]
    has_permission_on :performances, :to=>[:view, :make, :manage, :delete]
    has_permission_on :admin_ticket_classes, :to=>[:make,:manage]
    has_permission_on :admin_flex_pass_offers, :to=>[:make, :manage, :view]
    has_permission_on :admin_addresses, :to=>[:view_email]
    has_permission_on :admin_reports, :to=>[:box_office_reports]
    has_permission_on :admin_membership_orders, :to=>[:view]
    has_permission_on :admin_special_features, :to=>[:view,:manage]
  end

  role :admin do
    includes :box_office
    has_permission_on :theaters, :to=>[:delete,:make]
    has_permission_on :admin_theaters, :to=>[:make]
    has_permission_on :admin_orders, :to=>[:cancel]
    has_permission_on :orders, :to=>[:delete]
    has_permission_on :admin_ticket_orders, :to=>[:hold,:unclaimed, :fulfill]
    has_permission_on :admin_refund_orders, :to=>[:make]
    has_permission_on :admin_users, :to=>[:view, :manage, :delete, :make]
    has_permission_on :productions, :to=>:delete
    has_permission_on :admin_reports, :to=>[:reconciliation_reports, :membership_reports, :fulfill_donations]
    has_permission_on :admin_default_ticket_classes, :to=>[:view, :make, :manage]
  end
end

privileges do
  privilege :make, :includes => [:create, :new]
  privilege :view, :includes => [:index, :show, :read]
  privilege :manage, :includes => [:edit, :update]
end