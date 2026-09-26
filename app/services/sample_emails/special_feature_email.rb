module SampleEmails
  # Special feature form, Custom Email: a confirmation for a sample performance
  # carrying a sample feature built from the form. The feature is saved inside
  # the same rolled-back transaction as the order (SampleOrderBuilder's own
  # transaction can't take it: a Rollback raised in a nested block is swallowed
  # and the outer one commits).
  class SpecialFeatureEmail < Base
    self.email_name = 'confirmation email'

    def self.authorized?(ability, _context)
      ability.can?(:update, SpecialFeature)
    end

    def deliver!
      ActiveRecord::Base.transaction do
        order = SampleOrderBuilder.build_sample_order(default_theater, recipient, {},
                                                      performance_attrs: { special_feature_ids: [sample_feature.id] })
        OrderMailer.ticket_confirmation(order).deliver_now
        raise ActiveRecord::Rollback
      end
    end

    private

    # Unvalidated: the draft usually shares its short name with the saved
    # feature. Always active, since inactive features are left out of emails
    # and the sample would show nothing.
    def sample_feature
      @sample_feature ||= SpecialFeature.new(draft_feature_attrs.merge(status: SpecialFeature::ACTIVE)).tap do |feature|
        feature.save!(validate: false)
      end
    end

    def draft_feature_attrs
      params.require(:special_feature).permit(:short_name, :description, :email_description)
    end
  end
end
