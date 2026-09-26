module SampleEmails
  # Performance form, Custom Email: a confirmation for the real production whose
  # sample performance takes the form's custom feature texts and features.
  class PerformanceEmail < Base
    self.email_name = 'confirmation email'

    def self.authorized?(ability, context)
      production = context_production(context)
      production.present? && ability.can?(:update, Performance) && ability.can?(:update, production)
    end

    def deliver!
      with_sample_order(production.theater, saved_production_attrs(production),
                        performance_attrs: draft_performance_attrs) do |order|
        OrderMailer.ticket_confirmation(order).deliver_now
      end
    end

    private

    def draft_performance_attrs
      draft = params.require(:performance).permit(:special_feature_display_markdown,
                                                  :special_feature_email_markdown, special_feature_ids: [])
      { special_feature_display_markdown: draft[:special_feature_display_markdown],
        special_feature_email_markdown: draft[:special_feature_email_markdown],
        # the check boxes post a blank entry so that none can be chosen
        special_feature_ids: Array(draft[:special_feature_ids]).compact_blank }
    end
  end
end
