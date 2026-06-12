class ExpireFlexPass
  @queue = :maintenance

  def self.perform(flex_pass_id)
    begin
      fp = FlexPass.find(flex_pass_id)
      fp.active = false
      fp.save!
    rescue ActiveRecord::RecordNotFound
    end
  end
end
