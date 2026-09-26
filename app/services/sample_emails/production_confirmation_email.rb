module SampleEmails
  # Production form, Additional Confirmation Message: the saved production
  # overlaid with whatever the form posted, so the sample shows what a save
  # would send.
  class ProductionConfirmationEmail < Base
    self.email_name = 'confirmation email'

    DRAFT_FIELDS = %i[name confirmation_message follow_up_message_2 survey_link mailing_list_link
                      production_class allow_late_seating venue_id].freeze

    def self.authorized?(ability, context)
      production = context_production(context)
      production.present? && ability.can?(permission, production)
    end

    def self.permission
      :send_sample_confirmation
    end

    def deliver!
      with_sample_order(production.theater, draft_production_attrs) { |order| send_mail(order) }
    end

    private

    def send_mail(order)
      OrderMailer.ticket_confirmation(order).deliver_now
    end

    def draft_production_attrs
      draft = params.require(:production).permit(*DRAFT_FIELDS).to_h.symbolize_keys
      if draft.key?(:allow_late_seating)
        draft[:allow_late_seating] = ActiveModel::Type::Boolean.new.cast(draft[:allow_late_seating])
      end
      saved_production_attrs(production).merge(draft)
    end
  end
end
