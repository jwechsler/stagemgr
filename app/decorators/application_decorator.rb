class ApplicationDecorator < Draper::Decorator
  # Define methods for all decorated objects.
  # Helpers are accessed through `helpers` (aka `h`). For example:
  #
  #   def percent_amount
  #     h.number_to_percentage object.amount, precision: 2
  #   end

  def show_as_checkmark
    h.raw("<span class=\"fa fa-check\" />")
  end

  protected
  def make_image_url(img, dimensions)
    if dimensions.nil?
      h.url_for(img)
    else
      width, height = dimensions[0] if dimensions[0].class.eql?(Array)
      # replace with version 6
      h.url_for(img.variant(resize_and_pad: [width, height, gravity: 'north']).processed)
      #h.url_for(img.variant(resize: "#{width}x#{height}"))
    end
  end

  def make_image_tag(img, dimensions)
    if dimensions.nil? || dimensions.empty?
      h.image_tag(img)
    else
      width, height = dimensions[0] if dimensions[0].class.eql?(Array)
      # replace with version 6:
      h.image_tag(img.variant(resize_and_pad: [width, height, gravity: 'north']).processed)
      #h.image_tag(img.variant(resize: "#{width}x#{height}>"))
    end
  end

end
