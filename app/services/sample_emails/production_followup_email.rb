module SampleEmails
  # Production form, Follow-up message. The survey and mailing list links come
  # from the form too: the sample production once dropped them, and a working
  # survey override previewed as the house-wide default.
  class ProductionFollowupEmail < ProductionConfirmationEmail
    self.email_name = 'follow-up email'

    def self.permission
      :send_sample_followup
    end

    private

    # standard_followup is presenter-aware, so the sample shows the format (and
    # sender) this theater's patrons will actually receive.
    def send_mail(order)
      OrderMailer.standard_followup(order).deliver_now
    end
  end
end
