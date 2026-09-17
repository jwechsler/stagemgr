# frozen_string_literal: true

module MembershipCards
  # A font the text renderer can ask Pango for: an optional file to register
  # plus the family description Pango matches against. `path` is nil for the
  # fontconfig fallbacks (Helvetica), which are resolved by name alone -- on
  # the production Mac that is the real Helvetica, in the Docker image and CI
  # fontconfig's metric alias hands back Nimbus Sans.
  Font = Struct.new(:path, :pango_family) do
    def self.fallback(pango_family)
      new(nil, pango_family)
    end

    def fallback?
      path.nil?
    end
  end
end
