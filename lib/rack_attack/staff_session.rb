module RackAttack
  # True when the request carries a live Authlogic session for a staff user
  # (administrator or box office). Used by the rack-attack safelist so staff
  # behind one office IP are never throttled by each other's traffic.
  #
  # Reads the two keys UserSession writes into the Rails session:
  # 'user_credentials' (persistence token) and 'user_credentials_id' (user id).
  # The answer is memoised in Rails.cache for CACHE_TTL, keyed on the user id
  # and a SHA-256 digest of the token. Never raises: a failed check returns
  # false, so a DB hiccup cannot take the site down from inside middleware.
  module StaffSession
    CACHE_TTL = 60.seconds
    SESSION_TOKEN_KEY = 'user_credentials'.freeze
    SESSION_ID_KEY = 'user_credentials_id'.freeze

    def self.staff?(req)
      session = req.env['rack.session']
      return false unless session

      id = session[SESSION_ID_KEY]
      token = session[SESSION_TOKEN_KEY]
      return false if id.blank? || token.blank?

      # Digest, not the raw token: production's default FileStore writes the
      # cache key into the file name on disk.
      key = ['rack-attack', 'staff', id, Digest::SHA256.hexdigest(token.to_s)]
      Rails.cache.fetch(key, expires_in: CACHE_TTL) do
        live_staff_user?(id, token)
      end
    rescue StandardError => e
      Rails.logger.warn("[rack-attack] staff check failed: #{e.class}: #{e.message}")
      false
    end

    def self.live_staff_user?(id, token)
      User.where(is_administrator: true).or(User.where(is_box_office_user: true))
          .where.not(status: User::INACTIVE)
          .exists?(id: id, persistence_token: token)
    end
    private_class_method :live_staff_user?
  end
end
