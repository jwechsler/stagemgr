class MembershipOrderMailingListExport < ReportExport
  @queue = :report

  def self.perform(starting_date, ending_date, trg_lists, membership_offer_ids, reporting_user_id, theater_ids = [])
    report = MembershipOrderMailingList.new(starting_date, ending_date, trg_lists, membership_offer_ids,
                                            reporting_user_id, theater_ids: theater_ids)
    send_report(report)
  end
end
