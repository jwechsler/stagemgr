class UserDecorator < ApplicationDecorator
  delegate_all

  def email
    h.link_to(object.email, [:admin, object], class: "#{'strike' if object.inactive?}")
  end

  def last_request_at
    object.last_request_at.to_s
  end

  def privs
    labels = []
    labels << h.raw('<span class="success label">Administrator</span>') if object.is_administrator?
    labels << h.raw('<span class="success label">Box Office</span>') if object.is_box_office_user?
    object.theaters.each do |t|
      labels << h.raw("<span class=\"label secondary\">#{t}</span>")
    end
    h.safe_join(labels, ' ')
  end

  def dt_actions
    h.link_to('Edit', [:edit, :admin, user], class: 'tiny button')
  end

  # Define presentation-specific methods here. Helpers are accessed through
  # `helpers` (aka `h`). You can override attributes, for example:
  #
  #   def created_at
  #     helpers.content_tag :span, class: 'time' do
  #       object.created_at.strftime("%a %m/%d/%y")
  #     end
  #   end
end
