# frozen_string_literal: true

# Who gets the crash mail, from server.yml's email.addresses block.
#
# Extracted from config/environments/production.rb (where the addresses used to
# be hard-coded Theater Wit literals) so the resolution is testable without
# booting the production environment -- same precedent as lib/mailer_url_options.rb,
# and required the same way, before the autoloaders exist.
module ExceptionRecipients
  SENDER_NAME = 'Exception Notifier'
  RECIPIENT_KEY = 'exception_notifications'
  SENDER_KEY = 'software_address'

  # Recipients for ExceptionNotification, in preference order:
  # email.addresses.exception_notifications, else software_address. Always an
  # Array, always without blanks -- an empty result means the middleware must
  # not be installed at all (exception_notification raises while handling the
  # real exception if it tries to deliver to nobody).
  def self.for(email_addresses)
    addresses = email_addresses || {}
    Array(addresses[RECIPIENT_KEY].presence || addresses[SENDER_KEY]).map { |a| a.to_s.strip }.reject(&:empty?)
  end

  # Envelope sender: the application's own address, not one of the recipients,
  # so replies and bounces go somewhere a human reads. Nil when nothing is
  # configured, which only happens when .for is empty too.
  def self.sender_address(email_addresses)
    addresses = email_addresses || {}
    address = addresses[SENDER_KEY].to_s.strip.presence || self.for(addresses).first
    return nil if address.nil?

    %("#{SENDER_NAME}" <#{address}>)
  end
end
