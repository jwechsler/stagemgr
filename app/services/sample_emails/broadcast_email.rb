module SampleEmails
  # Email attendees modal: the broadcast as one attendee of the real production
  # would get it. The page names the production; the modal's form adds the
  # performance (filled in when the modal opens) and its fields at the top level.
  class BroadcastEmail < Base
    self.email_name = 'attendee email'

    # The page's check: the performance isn't chosen until the modal opens.
    def self.visible?(ability, context)
      production = context_production(context)
      production.present? && ability.can?(:email_attendees, Performance) && ability.can?(:update, production)
    end

    # The send's check: a performance of that production the user may email.
    def self.authorized?(ability, context)
      return false unless visible?(ability, context) && context[:performance_id].present?

      performance = Performance.find_by(id: context[:performance_id])
      performance.present? && performance.production_id == context_production(context).id &&
        ability.can?(:email_attendees, performance)
    end

    def deliver!
      with_sample_order(production.theater, saved_production_attrs(production)) do |order|
        # Never queue_broadcast!: that queues an OutreachTask for every real
        # attendee. The mailer finds this row as the performance's latest.
        order.performance.broadcasts.create!(user: user, sent_at: Time.current, **draft_broadcast_attrs)
        OrderMailer.custom_performance_broadcast(order).deliver_now
      end
    end

    private

    def draft_broadcast_attrs
      params.slice(:subject, :from_address, :body).permit(:subject, :from_address, :body).to_h.symbolize_keys
    end
  end
end
