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
    return "" unless img.respond_to?(:attached?) && img.attached?

    if dimensions.nil? || dimensions.empty?
      h.url_for(img)
    else
      width, height = parse_dimensions(dimensions[0])
      h.url_for(img.variant(format: 'png', resize_and_pad: [width, height, gravity: 'centre', alpha: true])&.processed)
    end
  end

  def make_image_tag(img, dimensions)
    return "" unless img.respond_to?(:attached?) && img.attached?

    if dimensions.nil? || dimensions.empty?
      h.image_tag(img)
    else
      width, height = parse_dimensions(dimensions[0])
      begin
        h.image_tag(img.variant(format: 'png',
                                resize_and_pad: [width, height,
                                                 gravity: 'centre', alpha: true])&.processed)
      rescue ActiveStorage::FileNotFoundError
        ""
      end
    end
  end

  def parse_dimensions(dim)
    return dim if dim.is_a?(Array)

    dim.to_s.scan(/\d+/).map(&:to_i)
  end
end
