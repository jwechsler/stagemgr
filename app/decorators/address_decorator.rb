class AddressDecorator < ApplicationDecorator
  delegate_all

  # Define presentation-specific methods here. Helpers are accessed through
  # `helpers` (aka `h`). You can override attributes, for example:
  #
  #   def created_at
  #     helpers.content_tag :span, class: 'time' do
  #       object.created_at.strftime("%a %m/%d/%y")
  #     end
  #   end

  def visits(current_user)
    (current_user.is_theater_user? ? object.orders_processed(current_user.theater_ids) : object.orders_processed )
  end

  def full_name
    h.link_to(object.full_name, [:admin, object])
  end

  def description
    if object.is_current_flex_pass_holder?
      "FlexPass Holder [#{object.flex_passes.map { |fp| h.link_to(fp.code, [:admin, fp])}.join(',')}]"
    end
  end

end
