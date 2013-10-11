class TrgExport
  @queue = :report
  include Admin::ReportsHelper

  def self.perform(production_id, reporting_user_id)
    production = Production.find(production_id)
    season_tag = production.season.to_i + 1
    all_attendees = production.attendees
    orders = TicketOrder.includes(:address, :payments, :theater, {:performance=>:production}).where('performances.production_id = ?', production.id)
    order_set = orders.to_set
    members_by_email = Admin::ReportsHelper.attendees_on_email_list(production)
    reports = Hash['ALL' => Array.new,
                         'MEM' => Array.new,
                         'STB' => Array.new,
                         'EMA' => Array.new,
                         'REN' => Array.new,
                         'CMP' => Array.new]
    consolidation_code = production.theater.is_default? ? 'ALL' : 'REN'
    all_attendees.each do |address|
      hash = Admin::ReportsHelper.trg_hash(address)
      address_orders = order_set & address.orders
      buyer_type = case
      when address_orders.size == 0
        nil
      when address_orders.select{|o| o.paid_with_membership?}.size > 0
        'MEM'
      when address_orders.inject(0) { |t,o| t + o.total}  == 0
        'CMP'
      else
        'STB'
      end
      reports[consolidation_code] << hash
      reports[buyer_type] << hash unless buyer_type.nil?
    end

    members_by_email.each do |member_record|
      hash = Admin::ReportsHelper.trg_hash_from_myemma(member_record[1])
      reports['EMA'] << hash
    end

    # now, output the various production reports
    reports.keys.each do |key|
      if reports[key].size > 0
        file_name = "/tmp/#{season_tag}_#{key}_#{Admin::ReportsHelper.safe_title(production.name)}.csv"
        file_store = FileStore.new
        file_store.worker = FileStore::REPORT
        file_store.user_id = reporting_user_id
        file_store.notes = 'TRGarts csv export format'
        file_store.save!
        Admin::ReportsHelper.save_report_as_csv(file_name, TRG_IMPORT_HEADERS, reports[key], file_store)
      end
    end
  end
end
