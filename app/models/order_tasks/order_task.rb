class OrderTask < ActiveRecord::Base
  TASK_STATUSES = (
      COMPLETED, FAILED = "Completed", "Failed"
  )
  acts_as_audited

  belongs_to :order

  validates_presence_of :order

  def run
    self.attempts += 1
    self.status =  self.execute! ?  COMPLETED : FAILED
  end

end
