class TheaterDecorator < ApplicationDecorator
  delegate_all

  def dt_actions(current_user)
    links = []
    links << (current_user.can?(:edit, object) ? h.link_to('Edit', [:edit, :admin, object], :id=>"edit_#{object.name.downcase.gsub(' ','_')}", :class=>'tiny button') : '')
    links << (current_user.can?(:destroy, object) ? h.link_to('Destroy', [:admin, object], :confirm => 'Are you sure?', :method => :delete, :class=>'tiny alert button') : '')
    h.safe_join(links, ' ')
  end

  def url
    begin
      host = URI.parse(object.url).host
    rescue URI::InvalidURIError
      host = ""
    end
    h.link_to(host,object.url)
  end

  def name
    h.link_to(object.name, [:admin, object])
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
