# frozen_string_literal: true

module MembershipCards
  # The entry point: one membership in, one printable PNG out.
  #
  #   png = MembershipCards::Card.new(membership).png
  #
  # Gathers the four things that vary per card -- the patron's name and photo,
  # the member code, and the year they first became a member -- and hands
  # them with the offer's artwork to a RenderProcess (a child process running
  # the Renderer). Raises RenderError when the offer has no background or the
  # render fails.
  class Card
    attr_reader :membership

    def initialize(membership)
      @membership = membership
    end

    def png
      offer = membership.membership_offer
      raise RenderError, "offer #{offer.id} has no card background" unless offer.card_available?

      Assets.with(offer, photo) do |assets|
        RenderProcess.run(
          Renderer::Inputs.new(
            background_path: assets.background_path, front_path: assets.front_path,
            photo_path: assets.photo_path, name_font: assets.name_font, label_font: assets.label_font,
            name: membership.address.full_name, member_number: membership.member_code,
            year: membership.patron_member_since_year.to_s
          )
        )
      end
    end

    def filename
      "member-card-#{membership.member_code.to_s.parameterize}.png"
    end

    private

    def photo
      attachment = membership.address&.photo
      attachment if attachment&.attached?
    end
  end
end
