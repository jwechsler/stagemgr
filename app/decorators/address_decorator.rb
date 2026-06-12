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

  def photo_url(*dimensions)
    make_image_url(object.photo, dimensions)
  end

  def photo(*dimensions)
    make_image_tag(object.photo, dimensions)
  end

  def visits(current_user)
    (current_user.is_theater_user? ? object.orders_processed(current_user.theater_ids) : object.orders_processed)
  end

  def full_name
    h.link_to(object.full_name, [:admin, object])
  end

  def description
    d = ''
    if object.is_current_flex_pass_holder?
      passes = object.flex_passes.filter_map do |fp|
        if fp.flex_pass_line_item&.order
          h.link_to(fp.code, [:admin, fp.flex_pass_line_item.order])
        end
      end
      passes = h.safe_join(passes, ',')
      d += "FlexPass Holder [#{h.raw(passes)}]"
    end
    if object.is_current_member?
      memberships = []
      object.memberships.select { |membership| membership.active? }.each { |membership|
        memberships << h.link_to(membership.member_code, [:admin, membership.membership_order])
      }
      if memberships.size > 0
        memberships = h.safe_join(memberships, ',')
        d = (d.blank? ? '' : "#{d}; ") + "Member [#{h.raw(memberships)}]"
      end
    end
    h.raw d
  end
end
