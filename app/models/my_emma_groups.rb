# frozen_string_literal: true

# The standing MyEmma groups a patron joins when they tick the mailing-list box,
# named in the `my_emma:` block of config/server.yml so a house can point them at
# its own groups.
#
# Three states per key, deliberately distinct:
#
#   key absent from server.yml -> the historical name ('Newsletter', 'Flash
#                                 Offers'), so an install whose config predates
#                                 these keys keeps the behaviour it had
#   key present but blank      -> nobody is added to that group; an explicit
#                                 opt-out, not a lookup for ""
#   key present with a name    -> that group
#
# Ids are cached for CACHE_TTL rather than for the life of the process. The gem
# resolves a name by listing every group in the account, so a lookup per order is
# expensive; but a permanent memo would go on serving an id from before a group
# was renamed. (It used to be a class variable behind
# `return if defined? @@newsletter_id`, which answered nil on every call after
# the first -- so a worker stopped adding anyone to any group at all.)
module MyEmmaGroups
  CONFIG_SECTION = 'my_emma'
  NEWSLETTER = 'newsletter_group'
  COUPON = 'coupon_group'

  DEFAULT_NAMES = { NEWSLETTER => 'Newsletter', COUPON => 'Flash Offers' }.freeze
  KEYS = DEFAULT_NAMES.keys.freeze

  CACHE_TTL = 5.minutes

  class << self
    # The configured group name, or nil when this house has switched the group
    # off by blanking the key.
    def name_for(key)
      section = config_section
      return DEFAULT_NAMES[key] unless configured?(section, key)

      lookup(section, key).presence
    end

    # The MyEmma id behind that name, or nil when the group is switched off or
    # does not exist in the account (which is worth a log line: patrons are
    # opting in to nothing).
    def id_for(key)
      name = name_for(key)
      return nil if name.nil?

      id_for_name(name)
    end

    def id_for_name(name)
      Rails.cache.fetch("myemma:group:#{name}", expires_in: CACHE_TTL) do
        id = MyEmma::Group.find_by_group_name(name)&.id
        if id.nil?
          Rails.logger&.warn("[MyEmma] no group named #{name.inspect} in this account — " \
                             'patrons opting in will not be added to it')
        end
        id
      end
    end

    private

    def config_section
      Rails.configuration.x.server_config&.[](CONFIG_SECTION) || {}
    end

    # server.yml parses to string keys (with_indifferent_access in the app), but
    # a spec may hand us a plain symbol-keyed Hash.
    def configured?(section, key)
      return false unless section.respond_to?(:key?)

      section.key?(key.to_s) || section.key?(key.to_sym)
    end

    def lookup(section, key)
      value = section[key.to_s]
      value.nil? ? section[key.to_sym] : value
    end
  end
end
