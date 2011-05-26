authorization do

  role :guest do
    has_permission_on :theaters, :to=>:read
    has_permission_on :productions, :to=>:read
    has_permission_on :performances, :to=>:read
    has_permission_on :flex_pass_offers, :to=>:read
    has_permission_on :orders, :to=>[:create,:read,:update]
  end

  role :theater_user do
    has_permission_on :admin_ticket_classes, :to=>[:view]
    has_permission_on :admin_theaters, :to=>[:view]
    has_permission_on :theaters, :to=>:read
    has_permission_on :admin_orders , :to=>[:view,:manage,:make]
    has_permission_on :admin_auto_complete, :to=>[:view]
    has_permission_on :orders, :to=>[:create, :update]
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
  end

  role :box_office do
    includes :theater_user
    has_permission_on :admin_theaters, :to=>[:manage]
    has_permission_on :theaters, :to=>[:create,:update,:read]
    has_permission_on :admin_exchange_orders, :to=>[:make]
    has_permission_on :admin_orders, :to=>[:fulfill]
    has_permission_on :admin_orders, :to=>[:hold]
    has_permission_on :productions, :to=>[:view, :make, :manage]
    has_permission_on :performances, :to=>[:view, :make, :manage, :delete]
    has_permission_on :admin_ticket_classes, :to=>[:make,:manage]
    has_permission_on :admin_flex_pass_offers, :to=>[:make, :manage, :view]
  end

  role :admin do
    includes :box_office
    has_permission_on :theaters, :to=>[:delete]
    has_permission_on :orders, :to=>[:delete]
    has_permission_on :admin_refund_orders, :to=>[:make]
    has_permission_on :admin_users, :to=>[:view, :manage, :delete, :make]
    has_permission_on :productions, :to=>:delete
  end
end
privileges do
  privilege :make, :includes => [:create, :new]
  privilege :view, :includes => [:index, :show, :read]
  privilege :manage, :includes => [:edit, :update]
end