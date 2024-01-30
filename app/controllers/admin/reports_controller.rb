require 'csv'

class Admin::ReportsController < Admin::ApplicationController
  authorize_resource
  # filter_access_to :trg_dump,:index


  include Admin::ReportsHelper
  helper_method :tidy_output

  # GET /admin/reports
  # GET /admin/reports.xml
  def index
    is_theater_user = !current_user.nil? && current_user.is_theater_user?
    @generated_reports = FileStore.where("worker = ? and user_id = ?", FileStore::REPORT, current_user.id).order('created_at desc')
    @generated_reports.select {|r| r.datafile.attached? }

    if is_theater_user then
      @productions = Production.accessible_by(current_ability,:read).order(press_opening_at: :desc)
      @flex_pass_offers = @productions.select { |p| !p.flex_pass_offer.nil? }.map { |p| p.flex_pass_offer }
    else
      @productions = Production.accessible_by(current_ability, :read).sellable.order(:name)
      @flex_pass_offers = FlexPassOffer.all
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
      format.xml { render :xml => @admin_report }
    end
  end

  # GET /admin/reports/new
  # GET /admin/reports/new.xml
  def new
    @admin_report = Admin::Report.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml { render :xml => @admin_report }
    end
  end

  # GET /admin/reports/1/edit
  def edit
    @admin_report = Admin::Report.find(params[:id])
  end

  def weekly_box_office
    @week_ending = Date.parse(params[:report][:week_ending])
    @headers, @report_data = build_weekly_box_office(@week_ending)
    if params['download_csv'].nil? then
      respond_to do |format|
        format.html
      end
    else
      send_report_as_csv('weekly_box_office', @headers, @report_data)
    end
  end

  def flexpass_sales
    @flex_pass_offer = FlexPassOffer.find(params[:report][:flex_pass_offer_id])
    @headers, @report_data = build_flexpass_sales(@flex_pass_offer, params['download_csv'].nil?)
    if params['download_csv'].nil? then
      respond_to do |format|
        format.html
      end
    else
      send_report_as_csv('flexpass_sales_by_date', @headers, @report_data)
    end

  end

  def order_dump
    @production = Production.accessible_by(current_ability, :read).find(params[:report][:production_id])
    @headers, @report_data = build_order_dump(@production)
    if params['download_csv'].nil? then
      respond_to do |format|
        format.html
      end
    else
      send_report_as_csv('production_attendee', @headers, @report_data)
    end
  end

  def daily_box_office_receipts
    @start_day = params[:start_day].to_date
    @end_day = params[:end_day].to_date
    if @start_day > @end_day then
      t = @start_day
      @start_day = @end_day
      @end_day = t
    end

    if (@end_day - @start_day) > 31 then
      flash[:error] = "You can only pull up to one month at a time"
      redirect_to admin_reports_path
    else
      @headers, @report_data = build_daily_box_office_receipts(@start_day, @end_day, !params['download_csv'].nil?)
      if params['download_csv'].nil? then
        respond_to do |format|
          format.html
        end
      else
        send_report_as_csv('daily_boxoffice_receipts', @headers, @report_data)

      end
    end
  end

  def donations_total
    @start_day = Date.parse(params[:start_day])
    @end_day = Date.parse(params[:end_day])
    if @start_day > @end_day then
      t = @start_day
      @start_day = @end_day
      @end_day = t
    end
    @headers, @report_data = build_donation_totals_dump(@start_day, @end_day, !params['download_csv'].nil?)
    if params['download_csv'].nil? then
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
    if @start_day > @end_day then
      t = @start_day
      @start_day = @end_day
      @end_day = t
    end

    @headers, @report_data = build_donations_dump(@start_day, @end_day, !params['download_csv'].nil?)
    if params['download_csv'].nil? then
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
    if params[:required_theaters].nil?
      required_theaters = []
    else
      required_theaters = params[:required_theaters].map{|t| t.to_i}
    end
    Resque.enqueue(TrgMinedExport, minimum_attended, minimum_revenue, start_day, required_theaters, current_user.id)
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

  def trg_dump
    production = Production.find(params[:report][:production_id])
    TrgExportJob.perform_later production.nil? ? 0 : production.id, current_user.id, can?(:view_email, Address)
    flash[:notice] = 'Your export is queued for generation. You\'ll recieve notification when the process is complete.'
    redirect_to admin_reports_path
  end

  def attended_dump
    starting_date = params[:starting_date].to_date
    ending_date = params[:ending_date].to_date

    Resque.enqueue(AttendedMailingListExport, starting_date, ending_date, current_user.id)
    flash[:notice] = 'Your export is queued for generation. You\'ll recieve notification when the process is complete.'
    redirect_to admin_reports_path
  end

  def donation_dump
    starting_date = params[:starting_date_donor].to_date
    ending_date = params[:ending_date_donor].to_date
    theater_id = params[:theater_id].to_i
    Resque.enqueue(DonorListExport, starting_date, ending_date, theater_id, current_user.id)
    flash[:notice] = 'Your export is queued for generation. You\'ll recieve notification when the process is complete.'
    redirect_to admin_reports_path
  end


  def fulfill_tickets
    @through_day = params[:through_day].to_date
    @headers, @report_data = build_fulfill_labels(@through_day)
    unless $TKTPRINT['service'].blank?
      flash[:notice] = fading_flash_message("Tickets printed")
      redirect_to admin_reports_path
    else
      send_report_as_csv('ticket_labels', @headers, @report_data)
    end
  end

  def production_sales_by_performance

    @production = Production.accessible_by(current_ability, :read).find(params[:report][:production_id])
    report = SalesByPerformanceReport.new([@production], !params['download_csv'].nil?)
    @headers, @report_data = report.create
    if params['download_csv'].nil? then
      respond_to do |format|
        format.html
      end
    else
      send_report_as_csv('production_totals', @headers, @report_data)
    end
  end

  # POST /admin/reports
  # POST /admin/reports.xml
  def create
    @admin_report = Admin::Report.new(params[:admin_report])

    respond_to do |format|
      if @admin_report.save
        format.html { redirect_to(@admin_report, :success => 'Report was successfully created.') }
        format.xml { render :xml => @admin_report, :status => :created, :location => @admin_report }
      else
        format.html { render :action => "new" }
        format.xml { render :xml => @admin_report.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /admin/reports/1
  # PUT /admin/reports/1.xml
  def update
    @admin_report = Admin::Report.find(params[:id])

    respond_to do |format|
      if @admin_report.update(params[:admin_report])
        format.html { redirect_to(@admin_report, :success => 'Report was successfully updated.') }
        format.xml { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml { render :xml => @admin_report.errors, :status => :unprocessable_entity }
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
    f = File.new('/tmp/debug.csv','w')
    f.puts(csv_string)
    f.close
    send_data csv_string, :type => "text/csv", :filename=>"#{title}.csv", :disposition=>'attachment'
  end

  def address_hash(a)
    {:last_name=>a.last_name,
                :first_name=>a.first_name,
                :street_address=>a.line1,
                :street_address_2=>a.line2,
                :city=>a.city,
                :state=>a.state,
                :postal_code=>a.zipcode,
                :phone=>a.phone,
                :email=>a.email,
                :address_id=>a.id}
  end

  def address_hash_from_order(o)
    unless o.address.blank?
      address_hash(o.address)
    else
         {:last_name=>'',
            :first_name=>'',
            :street_address=>'',
            :street_address_2=>'',
            :city=>'',
            :state=>'',
            :postal_code=>'',
            :phone=>'',
            :email=>''}
    end

  end

  def build_fulfill_labels(through_date)
    orders = TicketOrder.joins(:performance).joins(performance: :production).joins(:address).includes(:ticket_line_items).where(
        "orders.status = ? and performances.status = 'Active' and performances.performance_date <= ? and performances.performance_date > ? and productions.status in (?)",
        Order::PROCESSED, through_date, through_date - 1.day, Production.visible_statuses
      ).order("performances.performance_date, productions.production_code, performances.performance_code, addresses.last_name")

    orders = orders.sort_by{|o| [o.performance.performance_code, o.hold_under.blank? ? o.address.last_name : Address.parse_name(o.hold_under)[3] ]}
    report = Array.new
    headers = [:reserved_under, :performance_code, :tickets, :order_id, :profile, :member_id, :first_time, :last_24_months, :donor]
      orders.each { |o|
        if o.contains_tickets?
          logger.info("Fulfilling order #{o.id}")
          is_donor = o.address.is_donor?

          last24 = o.address.performances_attended(2.years.ago)
          member_id = o.membership_payments.size > 0 ? o.membership_payments.to_a.map { |mp| mp.membership.member_code }.join(',') + ' ' : ''
          attendance_code = member_id
          attendance_code += o.address.first_time_paying?(o) ? 'N' : 'R'
#          attendance_code += ("%03d" % last24).reverse
          attendance_code += "A" if is_donor
          if o.hold_under.blank?
            ticket_name = "#{o.address.last_name}" + ((o.address.last_name.blank? || o.address.first_name.blank?) ? '' : ', ') + (o.address.first_name.blank? ? '' : o.address.first_name.first)
          else
            cleaned_name, f_name, m_name, l_name, f_name2 = Address.parse_name(o.hold_under)
            ticket_name = "#{l_name}" + ((l_name.blank? || f_name.blank?) ? '' : ', ') + (f_name.blank? ? '' : f_name.first)
          end

          report << {:reserved_under=> ticket_name,
                     :performance_code => o.performance.performance_code,
                     :tickets => o.ticket_detail_description,
                     :profile => attendance_code,
                     :order_id => o.id,
                     :member_id => member_id,
                     :first_time => o.address.first_time_paying?(o),
                     :last_24_months => last24,
                     :donor => is_donor}
          o.transition_to!(Order::FULFILLED)
          o.save!
        end
      }
      [headers, report]
  end

  def build_flexpass_sales(offer, display_only = true)
    orders = offer.flex_passes.select{|fp| !fp.flex_pass_line_item.nil? }.map{|fp| fp.order}
    orders.sort! { |a,b| a.created_at <=> b.created_at }
    report = Array.new
    headers = [:order_date, :last_name, :first_name]
    headers += [:street_address, :street_address_2, :state, :city, :state, :postal_code, :phone] unless display_only
    headers += [:email] if can?(:view_email, :admin_addresses)
    headers += [:collected, :payout, :facility_fee, :tickets_remaining, :converted_balance, :status]

    fee = (offer.facility_fee.nil? ? 0 : offer.facility_fee).to_money
    totals = {:payout=>Money.new(0), :facility_fee=>Money.new(0), :display_class=>:report_summary_row,
      :converted_balance=>Money.new(0), :tickets_remaining=>0}
    orders.select { |o| !o.nil? && o.settled? }.sort { |o1, o2| o2.created_at <=> o1.created_at }.each { |o|
      flex_pass = o.flex_pass
      status = flex_pass.available? ?  o.status : flex_pass.expiration_date.to_s
      used = FlexPassPayment.where(flex_pass_id:flex_pass.id)
      if offer.flat_payout.blank? || offer.flat_payout == 0
        payout = FlexPassPayment.where('flex_pass_id = ?',flex_pass.id).sum(:amount).to_money
      else
        payout = (offer.flat_payout.nil? ? 0 : offer.flat_payout).to_money
      end
      converted_balance = flex_pass.available? ? 0.to_money : offer.price.to_money - fee.to_money - payout
      tickets_remaining = flex_pass.available? ? (offer.number_of_tickets - used.inject(0){|sum,p| sum + p.number_of_tickets }) : 0
      report << {:order_date=>o.created_at.to_date,
                 :payout=>payout,
                 :collected=>offer.price.to_money,
                 :facility_fee=>fee,
                 :tickets_remaining=>tickets_remaining,
                 :converted_balance=>converted_balance,
                 :status=>status,
                 :display_class=>:report_detail_row}.merge(address_hash_from_order(o))
      totals[:payout] += payout
      totals[:facility_fee] += fee
      totals[:converted_balance] += converted_balance
      totals[:tickets_remaining] += tickets_remaining

    }
    report << totals
    [headers, report]

  end


  def build_production_sales_by_performance(productions, include_classes = true, perfs = nil)
    report = SalesByPerformanceReport.new(productions.map{|prod| prod.id}, include_classes, perfs.nil? ? nil : perfs.map{|perf| perf.id})
    report.create
  end


  def build_weekly_box_office(week_ending)
    performances = Performance.where("performance_date >= ? and performance_date <= ? and exists (select * from productions where production_id = productions.id)",
                                     week_ending.beginning_of_week, week_ending.end_of_week)
    productions = performances.map { |p| p.production }.uniq
    report = SalesByPerformanceReport.new(productions.map{|prod| prod.id}, false, performances.map{|perf| perf.id})
    report.create
  end

  def grab_from_date_select(field_name, params)
    Date.new(params["#{field_name.to_s}(1i)"].to_i,
             params["#{field_name.to_s}(2i)"].to_i,
             params["#{field_name.to_s}(3i)"].to_i)
  end

  # columns_for_orders
  #
  # utility to generate internal list of keys for report generation
  #
  # @param build_for_dumpfile True if exporting to file
  # @param include_emails Include emails if user has permissions.  Defaults to false
  #
  # @return array of keys common to orders
  def columns_for_orders(build_for_dumpfile, include_emails = false)
    keys = [:order_date]
    keys += [:id, :first_name, :last_name, :street_address, :street_address_2, :city, :state, :postal_code, :phone] if build_for_dumpfile
    keys += [:email] if (build_for_dumpfile && (can?(:view_email, Address) || include_emails))
    keys += [:performance_code, :special_offer_code, :status, :description, :facility_fee] if build_for_dumpfile
    keys
  end

  def payment_bucket(payment)
    if payment.payment_type.nil?
      payment.class.to_s[0..-8]
    else
      payment.payment_type.display_name
    end
  end

  protected
  def create_hash_from_order_fields(order)
    row = Hash.new
    row[:order_date] = order.created_at.to_formatted_s(:long) unless order.created_at.nil?
    row[:id] = order.id
    row = row.merge(address_hash_from_order(order))
    row[:performance_code] = order.performance.performance_code if !order.performance.blank?
    row[:special_offer_code] = order.special_offer_code_used
    row[:status] = order.status
    row[:description] = order.description
    row[:order_total] = order.total_collected
    row[:order_revenue] = order.total_revenue
    row[:num_tickets]  = order.kind_of?(TicketOrder) ? order.number_of_tickets : 0
    row[:num_seats] = order.kind_of?(TicketOrder) ? order.number_of_seats : 0
    if order.performance.production.has_reserved_seating?
      row[:seat_assignments] = order.seats.map {|sa| sa.seat.location}.sort.join(', ')
    end
    row[:facility_fee] = order.ticketing_fee
    row
  end


  def build_daily_box_office_receipts(start_day, end_day, build_for_dumpfile = false)

    report = Array.new
    day_total = Hash.new
    zero_dollars = Money.new(0)
    keys = columns_for_orders(build_for_dumpfile) - [:order_date] + [:processed_on]
    payment_types = []

    current_date = start_day - 1.week

    payments = Payment.order("processed_on").where("processed_on >=:start_day and processed_on < :end_day", {:start_day=>start_day.to_time(:local), :end_day=>(end_day + 1.day).to_time(:local)})
    payments.each { |p|
      c_day = p.processed_on.to_s
      if c_day != current_date then
        current_date = c_day
        report << day_total unless day_total.empty?
        day_total = Hash.new
        day_total[:processed_on] = c_day
        day_total[:display_class] = :report_summary_row
      end
      amt = p.amount.nil? ? zero_dollars : p.amount.to_money
      bucket = payment_bucket(p)
      unless payment_types.include?(bucket)
        day_total[bucket] = zero_dollars
        payment_types << bucket
      end
      if day_total[bucket].nil?
        day_total[bucket] = amt
      else
        day_total[bucket] +=  amt
      end

      if build_for_dumpfile then
        row = create_hash_from_order_fields(p.order)

        row[p.class.to_s] = amt
        row[:display_class] = :report_detail_row
        report << row
      end


    }
    keys += payment_types.sort
    report << day_total
    [keys, report]
  end

  def build_donations_dump(start_day, end_day, build_for_dumpfile = false)
    donations = Order.all(:include=>[:address, :donation_line_items, :payments], :conditions=>["orders.status in (?) and payments.processed_on >= ? and payments.processed_on <= ?", Order::PROCESSED, start_day, end_day])
    report = Array.new
    keys = columns_for_orders(true) + [:total,:campaign]
    Order.transaction do
      donations.each { |o|
        total = o.total
        if total > 0
          row = create_hash_from_order_fields(o)
          row[:total] = total
          row[:campaign] = o.campaign
          report << row
        end
        o.transition_to!(Order::FULFILLED)
      }

    end
    [keys, report]
  end

  def build_donation_totals_dump(start_day, end_day, build_for_dumpfile = false)
    orders = DonationOrder.joins(:theater, :payments).includes([:theater, :payments]).where("orders.status in (?) and orders.created_at >= ? and orders.created_at < ?", Order::PROCESSED, start_day, end_day+1.day)
    reportdata = Array.new
    theater_ids = orders.pluck(:theater_id).uniq
    theaters = Theater.find(theater_ids)
    theater_hash = theaters.each_with_object({}) do |theater, hash|
      hash[theater.id] = {theater: theater.name, total_amount: Money.new(0), processing_fee: Money.new(0), due: Money.new(0)}
    end
    orders.each do |o|
       theater_hash[o.theater_id][:total_amount] += Money.new(o.total_paid*100.0)
       theater_hash[o.theater_id][:processing_fee] += Money.new(o.processing_fee*100.0)
       theater_hash[o.theater_id][:due] += Money.new((o.total_paid-o.processing_fee)*100.0)
    end
    theater_hash.values.each do |row|
      reportdata << { theater: row[:theater], total_amount:row[:total_amount], processing_fee: row[:processing_fee], due: row[:due] }
    end
    [[:theater, :total_amount, :processing_fee, :due],reportdata]
  end


end