class SeatMapDecorator < ApplicationDecorator
  delegate_all

  def label
    h.link_to(object.label, h.editor_admin_venue_seat_map_path(object.venue, object))
  end

  def base_image_map(*dimensions)
    make_image_tag(object.base_image_map, dimensions)
  end

  # SVG thumbnail of the map with its seat circles, for the venue's seat map
  # listing. Falls back to blank when no base image is attached.
  # Built with tag helpers rather than a partial: this runs mid-JSON-render
  # inside the datatable, where partial rendering through the ambient Draper
  # view context silently produces an empty string.
  def preview(max_height: 150)
    return '' unless object.base_image_map.attached?

    h.content_tag(:svg, version: '1.1', xmlns: 'http://www.w3.org/2000/svg',
                        'xmlns:xlink': 'http://www.w3.org/1999/xlink',
                        viewBox: "0 0 #{object.original_width} #{object.original_height}",
                        preserveAspectRatio: 'xMinYMin meet',
                        style: "height: #{max_height}px; width: auto; max-width: 100%; display: block;") do
      image = h.tag.image(width: object.original_width, height: object.original_height,
                          'xlink:href': base_image_map_url)
      circles = object.seats.map do |seat|
        h.tag.circle(class: 'seat available', cx: seat.origin_x, cy: seat.origin_y, r: seat.width,
                     style: (object.present_as_zoned ? h.zone_stroke_style(seat.zone, object) : nil))
      end
      h.safe_join([image] + circles)
    end
  end

  def base_image_map_url(*dimensions)
    make_image_url(object.base_image_map, dimensions)
  end

  def dt_actions
    actions = []
    actions << h.link_to('Edit', [:edit, :admin, object.venue, object], class: 'tiny button') if h.current_user.can?(
      :edit, SeatMap
    )
    if h.current_user.can?(
      :destroy, SeatMap
    )
      actions << ('<li>' + h.link_to('Destroy', [:admin, object.venue, object], confirm: 'Are you sure?',
                                                                                method: :delete, class: 'tiny alert button') + '</li>')
    end
    h.raw("<ul class=\"button-group\"><li>#{actions.join('</li><li>')}</li></ul>")
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
