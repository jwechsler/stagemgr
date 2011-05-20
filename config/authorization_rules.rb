authorization do

  role :guest do
    has_permission_on :theaters, :to=>:read
    has_permission_on :orders, :to=>[:create,:read,:update]
  end

  role :theater_user do
    has_permission_on :admin_theaters, :to=>[:view]
    has_permission_on :theaters do
      to :read
      if_attribute :id => is_in {user.theater_ids}
    end
    has_permission_on :admin_orders , :to=>[:view,:manage]
    has_permission_on :admin_auto_complete, :to=>[:view]
    has_permission_on :orders, :to=>[:create, :update]
    has_permission_on :orders, :to=>[:read] do
      if_attribute :theater_id => is_in {user.theater_ids}
    end

  end

  role :box_office do
    includes :theater_user
    has_permission_on :admin_theaters, :to=>[:edit]
    has_permission_on :theaters, :to=>[:create,:update,:read]
  end

  role :admin do
    includes :box_office
    has_permission_on :theaters, :to=>[:delete]
    has_permission_on :orders, :to=>[:delete]

  end
end
privileges do
  privilege :view, :includes => [:index, :show]
  privilege :manage, :includes => [:new, :edit]
end