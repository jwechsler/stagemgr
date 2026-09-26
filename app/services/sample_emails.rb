# "Send sample email" from the header of an email-flavored markdown editor
# (MarkdownEditorHelper, Admin::SampleEmailsController). Each kind builds a
# throwaway order from the enclosing form's unsaved values, sends the real
# mailer to the staff member, and leaves nothing behind: ticket samples roll
# back SampleOrderBuilder's transaction, the membership sample is never saved.
#
# KINDS is the whitelist: the controller refuses any kind not named here.
module SampleEmails
  KINDS = {
    'production_confirmation' => 'SampleEmails::ProductionConfirmationEmail',
    'production_followup' => 'SampleEmails::ProductionFollowupEmail',
    'ticket_class' => 'SampleEmails::TicketClassEmail',
    'default_ticket_class' => 'SampleEmails::DefaultTicketClassEmail',
    'resourced_ticket_class' => 'SampleEmails::ResourcedTicketClassEmail',
    'performance' => 'SampleEmails::PerformanceEmail',
    'special_feature' => 'SampleEmails::SpecialFeatureEmail',
    'membership_offer' => 'SampleEmails::MembershipOfferEmail',
    'performance_broadcast' => 'SampleEmails::BroadcastEmail'
  }.freeze

  # The service class for kind, or nil for anything not whitelisted.
  def self.for(kind)
    KINDS[kind.to_s]&.constantize
  end

  # The editor's check: whether to offer the button at all (Base.visible?).
  # context: the ids the kind needs to find its records (production_id, ...);
  # the helper passes the editor's sample: hash, the controller its params to
  # the kind's own .authorized?.
  def self.visible?(kind, ability, context)
    service = self.for(kind)
    service.present? && service.visible?(ability, context)
  end
end
