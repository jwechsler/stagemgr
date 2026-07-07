require 'csv'

class Admin::ReportsController < Admin::ApplicationController
  authorize_resource
  # filter_access_to :trg_dump,:index

  include Admin::ReportsHelper
  include ReportProcessor

  helper_method :tidy_output

  # GET /admin/reports
  # GET /admin/reports.xml
  def index
    is_theater_user = !current_user.nil? && current_user.is_theater_user?
    @generated_reports = FileStore.where('worker = ? and user_id = ?', FileStore::REPORT,
                                         current_user.id).order('created_at desc')
    @generated_reports.select { |r| r.datafile.attached? }

    @flex_pass_offers = if is_theater_user
                          Production.accessible_by(current_ability, :read)
                                    .order(press_opening_at: :desc)
                                    .filter_map(&:flex_pass_offer)
                        else
                          FlexPassOffer.all
                        end

    respond_to do |format|
      format.html # index.html.erb
    end
  end

  # GET /admin/reports/1
  # GET /admin/reports/1.xml
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.xml { render xml: @admin_report }
    end
  end

  # GET /admin/reports/new
  # GET /admin/reports/new.xml
  def new
    @admin_report = Admin::Report.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml { render xml: @admin_report }
    end
  end

  # GET /admin/reports/1/edit
  def edit
    @admin_report = Admin::Report.find(params[:id])
  end

  def weekly_box_office
    @week_ending = Date.parse(params[:report][:week_ending])
    @headers, @report_data = build_weekly_box_office(@week_ending)
    if params['download_csv'].nil?
      respond_to do |format|
        format.html
      end
    else
      send_report_as_csv('weekly_box_office', @headers, @report_data)
    end
  end

  def flexpass_sales
    dates = parse_date_params(starting_date: params[:starting_date], ending_date: params[:ending_date])
    @starting_date = dates[:starting_date].at_beginning_of_month
    @ending_date = dates[:ending_date].at_end_of_month
    flex_pass_offer_id = params[:flex_pass_offer_id].presence

    # Set flex pass offer name for view
    @flex_pass_offer_name = FlexPassOffer.find(flex_pass_offer_id).name unless flex_pass_offer_id.nil?

    process_report(
      report_class: FlexPassUsageReport,
      report_params: [@starting_date, @ending_date, flex_pass_offer_id, nil],
      job_class: FlexPassUsageExport,
      job_params: [@starting_date, @ending_date, flex_pass_offer_id],
      csv_filename: 'flexpass_sales',
      timeout: 60.seconds
    )
  end

  def daily_box_office_receipts
    @start_day = Date.parse(params[:start_day])
    @end_day = Date.parse(params[:end_day])

    # Swap dates if start date is after end date
    @start_day, @end_day = @end_day, @start_day if @start_day > @end_day

    # Override default max range - this report has 31-day limit
    days_span = (@end_day - @start_day).to_i
    if days_span > 31
      flash[:error] = 'You can only pull up to one month at a time'
      redirect_to admin_reports_path and return
    end

    @headers, @report_data = build_daily_box_office_receipts(@start_day, @end_day, !params['download_csv'].nil?)

    if params['download_csv'].nil?
      respond_to do |format|
        format.html
      end
    else
      send_report_as_csv('daily_boxoffice_receipts', @headers, @report_data)
    end
  end

  def donations_total
    @start_day = Date.parse(params[:start_day])
    @end_day = Date.parse(params[:end_day])
    if @start_day > @end_day
@start_day, @end_day = @end_day, @start_day
    end
    @headers, @report_data = build_donation_totals_dump(@start_day, @end_day, !params['download_csv'].nil?)
    if params['download_csv'].nil?
      respond_to do |format|
        format.html
      end
    else
      send_report_as_csv('donations_total', @headers, @report_data)
    end
  end

  def donations_dump
    @start_day = grab_from_date_select(:start_day, params[:report])
    @end_day = grab_from_date_select(:end_day, params[:report])
    if @start_day > @end_day
@start_day, @end_day = @end_day, @start_day
    end

    @headers, @report_data = build_donations_dump(@start_day, @end_day, !params['download_csv'].nil?)
    if params['download_csv'].nil?
      respond_to do |format|
        format.html
      end
    else
      send_report_as_csv('donations', @headers, @report_data)

    end
  end

  def mine_customer_data
    minimum_attended = params[:minimum_attended].to_i || 0
    minimum_revenue = params[:minimum_revenue].to_f || 0.0
    start_day = params[:from_day].to_date
    required_theaters = if params[:required_theaters].nil?
                          []
                        else
                          params[:required_theaters].map { |t| t.to_i }
                        end
    Resque.enqueue(TrgMinedExport, minimum_attended, minimum_revenue, start_day, required_theaters, current_user.id,
                   current_user.theater_ids)
    flash[:notice] = 'Your export is queued for generation. You\'ll recieve notification when the process is complete.'
    redirect_to admin_reports_path
  end

  def house_management_seating
    @date = params[:performance_day].to_date
    report = HouseManagementReport.new(@date)
    @headers, @report_data = report.create
    respond_to do |format|
      format.html
    end
  end

  # Exports production attendees segmented for TRG Arts. Includes email opt-in attendees
  def trg_dump
    production = Production.find(params[:report][:production_id])
    Resque.enqueue(TrgProductionAttendeeExportJob, production.nil? ? 0 : production.id, current_user.id,
                   can?(:view_email, Address), current_user.theater_ids)
    flash[:notice] = 'Your export is queued for generation. You\'ll recieve notification when the process is complete.'
    redirect_to admin_reports_path
  end

  # Trg Export by attended date.  Includes
  def attended_dump
    starting_date = params[:starting_date].to_date
    ending_date = params[:ending_date].to_date

    Resque.enqueue(AttendedMailingListExport, starting_date, ending_date, current_user.id, current_user.theater_ids)
    flash[:notice] = 'Your export is queued for generation. You\'ll recieve notification when the process is complete.'
    redirect_to admin_reports_path
  end

  def donation_dump
    dates = parse_date_params(starting_date: params[:starting_date_donor], ending_date: params[:ending_date_donor])
    theater_id = params[:theater_id].to_i

    Resque.enqueue(DonorListExport, dates[:starting_date], dates[:ending_date], theater_id, current_user.id,
                   current_user.theater_ids)
    flash[:notice] = "Your export is queued for generation. You'll receive notification when the process is complete."
    redirect_to admin_reports_path
  end

  def fulfill_tickets
    @through_day = params[:through_day].to_date
    @headers, @report_data = build_fulfill_labels(@through_day)
    if Rails.configuration.x.tktprint['service'].blank?
      send_report_as_csv('ticket_labels', @headers, @report_data)
    else
      flash[:notice] = "Tickets printed for #{@through_day}"
      redirect_to admin_reports_path
    end
  end

  def production_sales_by_performance
    @production = Production.accessible_by(current_ability, :read).find(params[:report][:production_id])
    report = SalesByPerformanceReport.new([@production], !params['download_csv'].nil?)
    @headers, @report_data = report.create
    if params['download_csv'].nil?
      respond_to do |format|
        format.html
      end
    else
      send_report_as_csv('production_totals', @headers, @report_data)
    end
  end

  def royalty_report
    @production = Production.accessible_by(current_ability, :read).find(params[:report][:production_id])
    report = RoyaltyReport.new([@production], !params['download_csv'].nil?)
    @headers, @report_data = report.create
    if params['download_csv'].nil?
      respond_to do |format|
        format.html
      end
    else
      send_report_as_csv('royalty_report', @headers, @report_data)
    end
  end

  def membership_usage
    if params[:membership_offer_id].present?
      @membership_offer = MembershipOffer.find(params[:membership_offer_id])
      first_payment, last_payment = @membership_offer.usage_date_range
      @starting_date = (first_payment || Date.current).to_date.at_beginning_of_month
      @ending_date = (last_payment || Date.current).to_date.at_end_of_month
    else
      dates = parse_date_params(starting_date: params[:starting_date], ending_date: params[:ending_date])
      @starting_date = dates[:starting_date].at_beginning_of_month
      @ending_date = dates[:ending_date].at_end_of_month
    end

    # Never report the current, still-incomplete month (matches the report's own cap).
    last_reportable_month_end = Date.current.at_beginning_of_month - 1.day
    @ending_date = [@ending_date, last_reportable_month_end].min

    process_report(
      report_class: MembershipUsageReport,
      report_params: [@starting_date, @ending_date, nil, @membership_offer&.id],
      job_class: MembershipUsageExport,
      job_params: [@starting_date, @ending_date],
      csv_filename: 'membership_usage',
      timeout: 120.seconds
    )
  end

  def membership_export
    @starting_date = params[:starting_date].to_date.at_beginning_of_month
    @ending_date = params[:ending_date].to_date.at_end_of_month
    trg_lists = params[:trg_lists]

    Resque.enqueue(MembershipOrderMailingListExport, @starting_date, @ending_date, trg_lists, current_user.id,
                   current_user.theater_ids)
    flash[:notice] = "Your export is queued for generation. You'll recieve notification when the process is complete."
    redirect_to admin_reports_path
  end

  def flex_pass_patron_report
    dates = parse_date_params(starting_date: params[:starting_date], ending_date: params[:ending_date])
    @starting_date = dates[:starting_date]
    @ending_date = dates[:ending_date]

    process_report(
      report_class: FlexPassPatronReport,
      report_params: [@starting_date, @ending_date, nil],
      job_class: FlexPassPatronReportJob,
      job_params: [@starting_date, @ending_date],
      csv_filename: 'flex_pass_patron_report',
      timeout: 60.seconds
    )
  end

  def order_dump
    production = Production.accessible_by(current_ability, :read).find(params[:report][:production_id])
    Resque.enqueue(ProductionAttendeeExport, production.id, can?(:view_email, Address), current_user.id)
    flash[:notice] = "Your export is queued for generation. You'll recieve notification when the process is complete."
    redirect_to admin_reports_path
  end

  # POST /admin/reports
  # POST /admin/reports.xml
  def create
    @admin_report = Admin::Report.new(params[:admin_report])

    respond_to do |format|
      if @admin_report.save
        format.html { redirect_to(@admin_report, success: 'Report was successfully created.') }
        format.xml { render xml: @admin_report, status: :created, location: @admin_report }
      else
        format.html { render action: 'new' }
        format.xml { render xml: @admin_report.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /admin/reports/1
  # PUT /admin/reports/1.xml
  def update
    @admin_report = Admin::Report.find(params[:id])

    respond_to do |format|
      if @admin_report.update(params[:admin_report])
        format.html { redirect_to(@admin_report, success: 'Report was successfully updated.') }
        format.xml { head :ok }
      else
        format.html { render action: 'edit' }
        format.xml { render xml: @admin_report.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /admin/reports/1
  # DELETE /admin/reports/1.xml
  def destroy
    @admin_report = Admin::Report.find(params[:id])
    @admin_report.destroy

    respond_to do |format|
      format.html { redirect_to(admin_reports_url) }
      format.xml { head :ok }
    end
  end

  private

  def send_report_as_csv(title, headers, data)
    csv_string = CSV.generate do |csv|
      csv << headers
      data.each do |r|
        csv << headers.map { |h| Admin::ReportsHelper.tidy_output(r[h]) } unless r.nil?
      end
    end
    f = File.new('/tmp/debug.csv', 'w')
    f.puts(csv_string)
    f.close
    send_data csv_string, type: 'text/csv', filename: "#{title}.csv", disposition: 'attachment'
  end

  def build_fulfill_labels(through_date)
    orders = TicketOrder.joins(:performance).joins(performance: :production).joins(:address).includes(:ticket_line_items).where(
      "orders.status = ? and performances.status = 'Active' and performances.performance_date <= ? and performances.performance_date > ? and productions.status in (?)",
      Order::PROCESSED, through_date, through_date - 1.day, Production.visible_statuses
    ).order('performances.performance_date, productions.production_code, performances.performance_code, addresses.last_name')

    orders = orders.sort_by do |o|
      [o.performance.performance_code,
       (o.hold_under.blank? ? o.address.last_name : Address.parse_name(o.hold_under)[2]).downcase]
    end
    report = []
    headers = %i[reserved_under performance_code tickets order_id profile member_id first_time
                 last_24_months donor]
    order_ids_to_fulfill = []

    orders.each do |o|
      next unless o.contains_tickets?

      logger.info("Queueing order #{o.id} for fulfillment")
      is_donor = o.address.is_donor?

      last24 = o.address.performances_attended(2.years.ago)
      member_id = if !o.membership_payments.empty?
                    o.membership_payments.to_a.map do |mp|
                      mp.membership.member_code
                    end.join(',') + ' '
                  else
                    ''
                  end
      attendance_code = member_id
      attendance_code += o.address.first_time_paying?(o) ? 'N' : 'R'
      #          attendance_code += ("%03d" % last24).reverse
      attendance_code += 'A' if is_donor
      if o.hold_under.blank?
        ticket_name = o.address.last_name.to_s + (o.address.last_name.blank? || o.address.first_name.blank? ? '' : ', ') + (o.address.first_name.blank? ? '' : o.address.first_name.first)
      else
        _, f_name, _, l_name, = Address.parse_name(o.hold_under)
        ticket_name = l_name.to_s + (l_name.blank? || f_name.blank? ? '' : ', ') + (f_name.blank? ? '' : f_name.first)
      end

      report << { reserved_under: ticket_name,
                  performance_code: o.performance.performance_code,
                  tickets: o.ticket_detail_description,
                  profile: attendance_code,
                  order_id: o.id,
                  member_id: member_id,
                  first_time: o.address.first_time_paying?(o),
                  last_24_months: last24,
                  donor: is_donor }

      # Collect order IDs for batch printing
      order_ids_to_fulfill << o.id
    end

    # Queue all orders for batch printing instead of synchronous transition
    unless order_ids_to_fulfill.empty?
      batch_id = PrintingService.print_orders(order_ids_to_fulfill, batch_type: :bulk)
      logger.info("Queued #{order_ids_to_fulfill.length} orders for printing in batch #{batch_id}")
    end

    [headers, report]
  end

  def build_production_sales_by_performance(productions, include_classes = true, perfs = nil)
    report = SalesByPerformanceReport.new(productions.map do |prod|
      prod.id
    end, include_classes, perfs.nil? ? nil : perfs.map do |perf|
                            perf.id
                          end)
    report.create
  end

  def build_weekly_box_office(week_ending)
    performances = Performance.where('performance_date >= ? and performance_date <= ? and exists (select * from productions where production_id = productions.id)',
                                     week_ending.beginning_of_week, week_ending.end_of_week)
    productions = performances.map { |p| p.production }.uniq
    report = SalesByPerformanceReport.new(productions.map { |prod| prod.id }, false, performances.map do |perf|
      perf.id
    end)
    report.create
  end

  def grab_from_date_select(field_name, params)
    Date.new(params["#{field_name}(1i)"].to_i,
             params["#{field_name}(2i)"].to_i,
             params["#{field_name}(3i)"].to_i)
  end

  # columns_for_orders
  #
  # utility to generate internal list of keys for report generation
  #
  # @param build_for_dumpfile True if exporting to file
  # @param include_emails Include emails if user has permissions.  Defaults to false
  #
  # @return array of keys common to orders

  def payment_bucket(payment)
    if payment.payment_type.nil?
      payment.class.to_s[0..-8]
    else
      payment.payment_type.display_name
    end
  end

  protected

  def build_daily_box_office_receipts(start_day, end_day, build_for_dumpfile = false)
    report = []
    day_total = {}
    zero_dollars = Money.new(0)
    keys = OrderReport.columns_for_orders(build_for_dumpfile,
                                          can?(:view_email, Address)) - [:order_date] + [:processed_on]

    current_date = start_day - 1.week

    payments = Payment.order('processed_on').where('processed_on >=:start_day and processed_on < :end_day',
                                                   { start_day: start_day.to_time(:local),
                                                     end_day: (end_day + 1.day).to_time(:local) })

    # Pre-collect all payment types for this date range
    payment_types = []
    payments.each do |p|
      bucket = payment_bucket(p)
      payment_types << bucket unless payment_types.include?(bucket)
    end
    payment_types.sort!

    payments.each do |p|
      c_day = p.processed_on.to_s
      if c_day != current_date
        current_date = c_day
        report << day_total unless day_total.empty?
        day_total = {}
        day_total[:processed_on] = c_day
        day_total[:display_class] = :report_summary_row
      end
      amt = p.amount.nil? ? zero_dollars : p.amount.to_money
      bucket = payment_bucket(p)
      if day_total[bucket].nil?
        day_total[bucket] = amt
      else
        day_total[bucket] += amt
      end

      next unless build_for_dumpfile

      row = OrderReport.create_hash_from_order_fields(p.order)

      # Initialize all payment type columns to zero
      payment_types.each { |pt| row[pt] = zero_dollars }
      # Set the actual payment amount for this payment type
      row[bucket] = amt
      row[:display_class] = :report_detail_row
      report << row
    end
    keys += payment_types
    report << day_total
    [keys, report]
  end

  def build_donations_dump(start_day, end_day, _build_for_dumpfile = false)
    donations = Order.all(include: %i[address donation_line_items payments],
                          conditions: ['orders.status in (?) and payments.processed_on >= ? and payments.processed_on <= ?', Order::PROCESSED,
                                       start_day, end_day])
    report = []
    keys = OrderReport.columns_for_orders(true) + %i[total campaign]
    Order.transaction do
      donations.each do |o|
        total = o.total_paid
        if total > 0
          row = create_hash_from_order_fields(o)
          row[:total] = total
          row[:campaign] = o.campaign
          report << row
        end
        o.transition_to!(Order::FULFILLED)
      end
    end
    [keys, report]
  end

  def build_donation_totals_dump(start_day, end_day, _build_for_dumpfile = false)
    orders = DonationOrder.joins(:theater, :payments).includes(%i[theater payments]).where(
      'orders.status in (?) and orders.created_at >= ? and orders.created_at < ?', Order::SETTLED_STATUSES, start_day, end_day + 1.day
    )
    reportdata = []
    theater_ids = orders.pluck(:theater_id).uniq
    theaters = Theater.find(theater_ids)
    theater_hash = theaters.to_h do |theater|
                     [theater.id, { theater: theater.name, total_amount: Money.new(0), processing_fee: Money.new(0), due: Money.new(0) }]
                   end
    orders.each do |o|
      theater_hash[o.theater_id][:total_amount] += Money.new(o.total_paid * 100.0)
      theater_hash[o.theater_id][:processing_fee] += Money.new(o.processing_fee * 100.0)
      theater_hash[o.theater_id][:due] += Money.new((o.total_paid - o.processing_fee) * 100.0)
    end
    theater_hash.each_value do |row|
      reportdata << { theater: row[:theater], total_amount: row[:total_amount], processing_fee: row[:processing_fee],
                      due: row[:due] }
    end
    [%i[theater total_amount processing_fee due], reportdata]
  end
end
