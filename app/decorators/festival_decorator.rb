class FestivalDecorator < ApplicationDecorator
  delegate_all

  def box_office_image_url(*dimensions)
    make_image_url(object.box_office_image, dimensions)
  end

  def box_office_image(*dimensions)
    make_image_tag(object.box_office_image, dimensions)
  end
end
