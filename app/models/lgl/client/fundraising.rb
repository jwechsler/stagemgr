# frozen_string_literal: true

module Lgl
  class Client
    # The fundraising-side LGL endpoints (campaigns, appeals, events, gifts)
    # used by donation replication. Every write passes +for_address_id:+
    # through the same read-only guard (Client#write) as constituent writes.
    module Fundraising
      CAMPAIGNS_PATH = '/campaigns'
      APPEALS_PATH = '/appeals'
      EVENTS_PATH = '/events'
      GIFTS_PATH = '/gifts'

      # Every campaign across all pages; the caller filters on is_active.
      def campaigns
        items = []
        each_page(CAMPAIGNS_PATH, []) { |page| items.concat(page.fetch('items', [])) }
        items
      end

      def search_appeals(name)
        search_items(APPEALS_PATH, search_term('name', name))
      end

      def create_appeal(attrs, for_address_id:)
        write(Net::HTTP::Post, APPEALS_PATH, attrs, for_address_id)
      end

      def update_appeal(id, attrs, for_address_id:)
        write(Net::HTTP::Patch, "#{APPEALS_PATH}/#{Integer(id)}", attrs, for_address_id)
      end

      # The event hash, or nil when LGL answers 404.
      def find_event(id)
        get("#{EVENTS_PATH}/#{Integer(id)}.json", [])
      rescue Error => e
        raise unless e.status == HTTP_NOT_FOUND

        nil
      end

      def search_events(name)
        search_items(EVENTS_PATH, search_term('name', name))
      end

      def create_event(attrs, for_address_id:)
        write(Net::HTTP::Post, EVENTS_PATH, attrs, for_address_id)
      end

      def update_event(id, attrs, for_address_id:)
        write(Net::HTTP::Patch, "#{EVENTS_PATH}/#{Integer(id)}", attrs, for_address_id)
      end

      # The gift hash, or nil when LGL answers 404.
      def find_gift(id)
        get("#{GIFTS_PATH}/#{Integer(id)}.json", [])
      rescue Error => e
        raise unless e.status == HTTP_NOT_FOUND

        nil
      end

      # Gifts whose external_gift_id is any of +ids+ (one "in|a,b" clause).
      def search_gifts_by_external_ids(ids)
        search_items(GIFTS_PATH, search_term('external_gift_ids', "in|#{Array(ids).join(',')}"))
      end

      def create_gift(constituent_id, attrs, for_address_id:)
        write(Net::HTTP::Post, "#{CONSTITUENTS_PATH}/#{Integer(constituent_id)}#{GIFTS_PATH}", attrs, for_address_id)
      end

      def update_gift(id, attrs, for_address_id:)
        write(Net::HTTP::Patch, "#{GIFTS_PATH}/#{Integer(id)}", attrs, for_address_id)
      end

      private

      # One page (PAGE_LIMIT) of {path}/search for a single q[] term.
      def search_items(path, term)
        get("#{path}/search", [['q[]', term], ['limit', PAGE_LIMIT]]).fetch('items', [])
      end
    end
  end
end
