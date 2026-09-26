module SampleEmails
  # Resourced ticket class form: global like a default ticket class, so the
  # sample is built at the default theater too.
  class ResourcedTicketClassEmail < DefaultTicketClassEmail
    def self.model
      ::ResourcedTicketClass
    end
  end
end
