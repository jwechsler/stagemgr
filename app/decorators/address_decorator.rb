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

  def description(current_user)
    d = ''
    if object.is_current_flex_pass_holder?
      passes = object.flex_passes.filter_map do |fp|
        h.link_to(fp.code, [:admin, fp.flex_pass_line_item.order]) if fp.flex_pass_line_item&.order
      end
      passes = h.safe_join(passes, ',')
      d += "FlexPass Holder [#{h.raw(passes)}]"
    end
    if object.is_current_member?
      memberships = membership_labels(current_user)
      unless memberships.empty?
        memberships = h.safe_join(memberships, ',')
        d = (d.blank? ? '' : "#{d}; ") + "Member [#{h.raw(memberships)}]"
      end
    end
    h.raw d
  end

  private

  # Theater users see the offer name as plain text; staff see the member code
  # linked to its order (or to the membership when it has no order).
  def membership_labels(current_user)
    object.memberships.select(&:active?).map do |membership|
      if current_user.is_theater_user?
        ERB::Util.html_escape(membership.membership_offer.name)
      else
        h.link_to(membership.member_code, [:admin, membership.membership_order || membership])
      end
    end
  end
end
