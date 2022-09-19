class PerformanceDecorator < ApplicationDecorator
  delegate_all

  def dt_actions
    actions = []
    
    if h.current_user.can? :update, Performance then
      actions << h.link_to('Edit', [:edit,:admin, object.production.theater, object.production, object], :id=>"edit_#{object.performance_code.gsub(' ','_')}", class: 'tiny button')
    end
    if h.current_user.can? :create, Performance then
      actions << h.link_to('Duplicate', [:duplicate, :admin, object.production.theater, object.production, object], :id=>"duplicate_#{object.performance_code.gsub(' ','_')}", class: 'tiny button' )
    end
    if h.current_user.can? :delete, Performance then
      # actions << h.link_to('Delete', [:destroy, :admin, object], :id=>"delete_#{object.performance_code.gsub(' ','_')}", :confirm=> "Are you sure?" , class: 'tiny button alert' )
    end
    h.safe_join(actions, ' ')
  end

  def performance_time
    object.performance_time.to_s(:hour_min)
  end

  def performance_code
    h.link_to(object.performance_code, [:admin, object.production.theater, object.production, object])
  end

  def status
    h.raw("<span class=\"label\">#{object.status}</span>" + (object.withhold_from_public? ? " <span class=\"label alert\">Blocked</span>" : ""))
  end

end
