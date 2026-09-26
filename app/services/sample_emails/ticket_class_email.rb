module SampleEmails
  # Ticket class form, purchase email annotation: a confirmation for the real
  # production whose sample ticket class takes the form's name, admission and
  # annotation (admission picks the in-person or virtual copy around it).
  class TicketClassEmail < Base
    self.email_name = 'confirmation email'

    def self.authorized?(ability, context)
      production = context_production(context)
      production.present? && ability.can?(:update, model) && ability.can?(:update, production)
    end

    def self.model
      ::TicketClass
    end

    def deliver!
      with_sample_order(production.theater, saved_production_attrs(production),
                        ticket_class_attrs: draft_ticket_class_attrs) do |order|
        OrderMailer.ticket_confirmation(order).deliver_now
      end
    end

    private

    def param_key
      self.class.model.model_name.param_key
    end

    def draft_ticket_class_attrs
      draft = params.require(param_key).permit(:class_name, :admission, :purchase_email_annotation)
      admission = draft[:admission].presence_in(TicketAdmission::ADMISSIONS.values) ||
                  TicketAdmission::ADMISSIONS[:in_person]
      { class_name: draft[:class_name].presence || 'General Admission',
        admission: admission,
        purchase_email_annotation: draft[:purchase_email_annotation] }
    end
  end
end
