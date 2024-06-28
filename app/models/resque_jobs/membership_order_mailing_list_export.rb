class MembershipOrderMailingListExport < ReportExport
  @queue = :report
  
  def self.perform(starting_date, ending_date, trg_lists, reporting_user_id)
    report = MembershipOrderMailingList.new(starting_date, ending_date, trg_lists, reporting_user_id)
    self.send_report(report)
  end

end
