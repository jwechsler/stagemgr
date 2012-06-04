class OrderTask < ActiveRecord::Base

  after_initialize :init

  TASK_STATUSES = (
      UNTRIED, COMPLETED, FAILED, CANCELLED = "Untried", "Completed", "Failed", "Cancelled"
  )
  acts_as_audited

  belongs_to :order

  validates_presence_of :order


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
    def run!
      self.attempts += 1
      success = self.execute!
      self.status =  success ?  COMPLETED : FAILED
      self.save!
      if success
        unless self.repeat_monthly_interval.blank?
          new_task = self.clone
          new_task.execute_at = Time.now + self.repeat_monthly_interval.months
          new_task.order_id = self.order_id
          new_task.attempts = 0
          new_task.status = UNTRIED
          new_task.save!
        end
      end
    end

  def cancel!
    self.status = CANCELLED
    self.save!
  end

  def uncompleted?
    status == UNTRIED
  end

  def self.run_pending
    pending_tasks = OrderTask.where("status in ('Untried','Failed') and attempts < 12 and execute_at < ?",Time.now)
    pending_tasks.each { |task|
      begin
        task.run!
      rescue => e
        puts "Could not run task #{task.id} on order #{task.order.id}: #{e}"
      end

    }

  end

  def cancel_with_order?
    true
  end

end
