# frozen_string_literal: true

module MembershipCards
  # Anything that stops a card from being produced: missing or stale artwork,
  # a name that cannot be made to fit, or a libvips failure. The controller
  # turns it into a flash message; the detail is logged.
  class RenderError < StandardError; end
end
