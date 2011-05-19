authorization do

  role :guest do
    has_permission_on :theaters, :to=>:read
  end

  role :theater_user do
    has_permission_on :admin_theaters, :to=>[:view]
    has_permission_on :theaters do
      to :read
      if_attribute :id => is_in {user.theater_ids}
    end
  end

  role :box_office do
    includes :theater_user
    has_permission_on :admin_theaters, :to=>[:edit]
    has_permission_on :theaters, :to=>[:create,:edit,:update,:read]
  end

  role :admin do
    includes :box_office
    has_permission_on :theaters, :to=>[:delete]

  end
end
privileges do
  privilege :view, :includes => [:index, :show]
  privilege :manage, :includes => [:edit, :destroy]
end