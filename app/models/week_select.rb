class WeekSelect
  attr_accessor :display, :value

  def initialize (which_date)
    self.display = which_date.beginning_of_week.to_s(:db)
    self.value = which_date.beginning_of_week
  end
end
