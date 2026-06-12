class ServiceItemTemplateDecorator < ApplicationDecorator
  delegate_all

  def name
    h.link_to(object.name, [:edit, :admin, object])
  end

  def amount
    h.number_to_currency(object.amount)
  end

  def facility_fee
    h.number_to_currency(object.facility_fee)
  end

  def dt_actions
    (h.current_user.can?(:edit,
                         object) ? h.link_to('Edit', [:edit, :admin, object], :id => "edit_#{object.name.downcase}",
                                                                              :class => 'tiny button') + " " : "") +
      (h.current_user.can?(:destroy,
                           object) ? link_to('Destroy', [:admin, object], :confirm => 'Are you sure?', :method => :delete,
                                                                          :class => 'tiny alert button') : "")
  end
end
