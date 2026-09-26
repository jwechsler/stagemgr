module SampleEmails
  # Default ticket class form (it shares the ticket class fields). A default
  # belongs to no production, so the sample builds one at the default theater.
  class DefaultTicketClassEmail < TicketClassEmail
    def self.model
      ::DefaultTicketClass
    end

    def self.authorized?(ability, _context)
      ability.can?(:update, model)
    end

    def deliver!
      with_sample_order(default_theater, ticket_class_attrs: draft_ticket_class_attrs) do |order|
        OrderMailer.ticket_confirmation(order).deliver_now
      end
    end
  end
end
