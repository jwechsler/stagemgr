class OrderTask < ApplicationRecord
  after_initialize :init

  TASK_STATUSES = (
      UNTRIED, COMPLETED, FAILED, CANCELLED = "Untried", "Completed", "Failed", "Cancelled"
    )

  belongs_to :order, inverse_of: :tasks

  validates :order, presence: true

  protected

  def execute!
    raise Exception.new("Unimplmented Task")
  end

  private

  def init
    self.attempts ||= 0
    self.status ||= UNTRIED
  end

  public

  # runs execute method for the order task.
  # if the order is in a transational state (like exchanging), postpone for 5 minutes.
  def run!
    return unless uncompleted? 

      if suppressed?
        cancel!
      elsif order.in_multi_transactional_state?
        self.execute_at = execute_at + 5.minutes
          save!
        else
          self.attempts += 1
          success = execute!
          self.status = success ? COMPLETED : FAILED
          save!
          if success
            if repeat_monthly_interval.present?
              new_task = dup
              new_task.execute_at = Time.now + repeat_monthly_interval.months
              new_task.order_id = order_id
              new_task.attempts = 0
              new_task.status = UNTRIED
              new_task.save!
            end
          end
      end
    
  end

  def cancel!
    self.status = CANCELLED
    save!
  end

  def uncompleted?
    (status == UNTRIED) or ((status == FAILED) and (attempts < 12))
  end

  def self.run_pending
    pending_tasks = OrderTask.where("status in ('Untried','Failed') and attempts < 12 and execute_at < ?", Time.now)
    pending_tasks.each do |task|
      begin
        task.run!
      rescue => e
        puts "Could not run task #{task.id} on order #{task.order.id}: #{e}"
      end
    end
  end

  def suppressed?
    order.payment_type.order_task_suppressions.any? do |s|
      next false unless s.task_type == type
      next true if s.method_name == 'ANY'
      next true if method_symbol.blank?

      s.method_name == method_symbol.to_s
    end
  end

  def cancel_with_order?
    true
  end

  def retry
    self.status = UNTRIED
    self.attempts = 0
    self
  end
end
