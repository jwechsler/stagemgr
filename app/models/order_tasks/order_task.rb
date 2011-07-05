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
      self.status =  self.execute! ?  COMPLETED : FAILED
      self.save!
    end

  def cancel!
    self.status = CANCELLED
    self.save!
  end

  def uncompleted?
    status == UNTRIED
  end

  def self.run_pending
    pending_tasks = OrderTask.where("status in ('Untried','Failed') and attempts < 3 and execute_at < ?",Time.now)
    pending_tasks.each { |task|
      task.run!
    }

  end
end
