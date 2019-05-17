module NotifyOnCompletion
  extend ActiveSupport::Concern

  module ClassMethods
    def notify_user_on_completion(filestore)
      unless filestore.user.nil?
        Rails.logger.debug("Notifying #{filestore.user.email} about report generation")
        NotificationMailer.file_generated(filestore).deliver_now
      end
    end
  end

end
