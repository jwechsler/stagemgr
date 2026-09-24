# Stamps a JobMetadata row with the completion time of every job that includes
# this concern, giving `JobMetadata.last_run("SomeJob")` an execution history.
#
# The hook MUST be a class method on the including job class. Resque resolves
# hooks with `job.methods` against the job class itself (see
# Resque::Plugin.get_hook_names), so a bare `def self.after_perform` in this
# module would land on the module object, never on the includer, and Resque
# would find no hook at all -- which is how this sat silently doing nothing.
#
# Resque only runs after_perform hooks when `perform` returned without raising,
# so a recorded run means a successful run.
module LoggedJob
  extend ActiveSupport::Concern

  module ClassMethods
    # Namespaced per Resque's hook naming convention; the arguments are the
    # ones `perform` was called with and are not used.
    def after_perform_record_last_run(*_args)
      JobMetadata.record_last_run(name)
    rescue StandardError => e
      # Bookkeeping must never fail the work that has already succeeded: a
      # raise here would send a completed job to the Resque failure queue.
      Rails.logger.error("LoggedJob: could not record last run for #{name} - #{e.message}")
    end
  end
end
