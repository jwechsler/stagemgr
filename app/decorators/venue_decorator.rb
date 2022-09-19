class VenueDecorator < ApplicationDecorator
  delegate_all

  def name
    h.link_to(object.name, [:admin, object])
  end

  def dt_actions
    actions = []
    actions << ("<li>" + h.link_to('Edit', [:edit, :admin, object], :id=>"edit_#{object.name.downcase.gsub(' ','_')}", :class=>'tiny button')+"</li>") if h.current_user.can?(:edit, object)
    actions << ("<li>" + h.link_to('Destroy', [:admin, object], :confirm => 'Are you sure?', :method => :delete, :class=>'tiny alert button') + "</li>") if h.current_user.can?(:destroy, object)
    h.raw('<ul class="button-group">' + actions.join(' ') + '</ul>')
  end

end
