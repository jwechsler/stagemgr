# "Send sample email" in the header of an email-flavored markdown editor
# (MarkdownEditorHelper, admin/markdown_editor.js). The URL names the kind and
# the ids it needs; the body is the enclosing form, unsaved edits and all. The
# sample goes to the signed-in staff member and nothing is saved (SampleEmails).
class Admin::SampleEmailsController < Admin::ApplicationController
  def create
    sample = SampleEmails.for(params[:kind])
    return render_result(false, 'Unknown kind of sample email.', :bad_request) if sample.nil?
    raise CanCan::AccessDenied unless sample.authorized?(current_ability, params)

    deliver(sample)
  end

  private

  def deliver(sample)
    sample.new(params: params, user: current_user).deliver!
    render_result(true, "Sample #{sample.email_name} sent to #{current_user.email}")
  rescue SampleEmails::Error, ActionController::ParameterMissing,
         ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid => e
    render_result(false, "Could not send the sample: #{e.message}", :unprocessable_entity)
  rescue StandardError => e
    Rails.logger.error("Sample #{params[:kind]} email failed: #{e.class}: #{e.message}\n" \
                       "#{e.backtrace&.first(10)&.join("\n")}")
    render_result(false, 'Could not send the sample email. The error has been logged.', :unprocessable_entity)
  end

  def render_result(success, message, status = :ok)
    render json: { success: success, message: message }, status: status
  end
end
