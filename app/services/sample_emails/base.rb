module SampleEmails
  # A problem the staff member can act on; the controller shows its message.
  class Error < StandardError; end

  # One kind of sample email. Subclasses implement .authorized? (the
  # controller's check, and by default the editor's, which hides the button)
  # and #deliver!, which reads the enclosing form's draft values from params.
  # A kind that names a production or performance authorizes against that
  # record, not just the class, and is denied when the id doesn't resolve.
  class Base
    # Names the email in the button's title and the reply ("confirmation email").
    class_attribute :email_name, instance_writer: false

    def self.authorized?(_ability, _context)
      raise NotImplementedError
    end

    # Whether the editor offers the button. Only differs from authorized? for a
    # kind whose ids arrive with the form at send time (BroadcastEmail).
    def self.visible?(ability, context)
      authorized?(ability, context)
    end

    def self.context_production(context)
      Production.find_by(id: context[:production_id]) if context[:production_id].present?
    end

    def initialize(params:, user:)
      @params = params
      @user = user
    end

    def deliver!
      raise NotImplementedError
    end

    private

    attr_reader :params, :user

    def recipient
      user.email
    end

    def with_sample_order(theater, production_attrs = {}, **overrides, &)
      SampleOrderBuilder.with_sample_order(theater, recipient, production_attrs, overrides, &)
    end

    def production
      @production ||= Production.find(params[:production_id])
    end

    def default_theater
      Theater.default_theater || raise(Error, 'No default theater is set up, so there is nowhere to build the sample.')
    end

    # SampleOrderBuilder's production attributes for a real production, so a
    # sample reads like that production's own mail.
    def saved_production_attrs(production)
      production.attributes.symbolize_keys.slice(
        :name, :confirmation_message, :follow_up_message_2, :survey_link, :mailing_list_link,
        :production_class, :allow_late_seating, :venue_id
      )
    end
  end
end
