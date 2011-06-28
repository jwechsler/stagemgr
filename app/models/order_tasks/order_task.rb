class OrderTask < ActiveRecord::Base

  after_initialize :init

  TASK_STATUSES = (
      UNTRIED, COMPLETED, FAILED = "Untried", "Completed", "Failed"
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

end
