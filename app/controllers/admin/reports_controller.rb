class Admin::ReportsController < Admin::ApplicationController

  helper_method :tidy_output

  # GET /admin/reports
  # GET /admin/reports.xml
  def index

    @productions = Production.with_permissions_to(:read).where(current_user.is_theater_user? ? "1=1" : "status != 'Inactive' and exists (select * from theaters where theaters.status != 'Inactive' and theaters.id = productions.theater_id)")
    if current_user.is_theater_user? then
      @productions.sort! { |p1, p2| p2.press_opening_at <=>p1.press_opening_at }
    else
      @productions.sort! { |p1, p2| p1.name <=> p2.name }
    end

    if current_user.is_theater_user? then
      @flex_pass_offers = @productions.select{|p| !p.flex_pass_offer.nil?}.map { |p| p.flex_pass_offer }
    else
      @flex_pass_offers = FlexPassOffer.find_all_by_active(true)
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

  def flexpass_sales
    @flex_pass_offer = FlexPassOffer.find(params[:report][:flex_pass_offer_id])
    @headers, @report_data, @totals = build_flexpass_sales(@flex_pass_offer)
    if params['download_csv'].nil? then
      respond_to do |format|
        format.html
      end
    else
      send_report_as_csv('flexpass_sales_by_date', @headers, @report_data, @totals)
    end

  end

  def production_sales_by_performance

    @production = Production.find(params[:report][:production_id])
    @headers, @report_data, @totals = build_production_sales_by_performance(@production)
    if params['download_csv'].nil? then
      respond_to do |format|
        format.html
      end
    else
      send_report_as_csv('production_totals', @headers, @report_data, @totals)
    end
  end

  # POST /admin/reports
  # POST /admin/reports.xml
  def create
    @admin_report = Admin::Report.new(params[:admin_report])

    respond_to do |format|
      if @admin_report.save
        format.html { redirect_to(@admin_report, :notice => 'Report was successfully created.') }
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
      if @admin_report.update_attributes(params[:admin_report])
        format.html { redirect_to(@admin_report, :notice => 'Report was successfully updated.') }
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


  def tidy_output(f)
    if f.is_a?(Time)
      f.to_s(:hour_min)
    else
      f
    end
  end

  private

  def send_report_as_csv(title, headers, data, totals)
    csv_string = FasterCSV.generate do |csv|
      csv << headers
      data.each do |r|
        csv << headers.map { |h| tidy_output(r[h]) }
      end
      csv << headers.map { |h| tidy_output(totals[h]) }
    end
    send_data csv_string, :type => "text/csv", :filename=>"#{title}.csv", :disposition=>'attachment'
  end

  def build_flexpass_sales(offer)
    orders = offer.flex_passes.map { |f| f.order }
    report = Array.new
    headers = [:order_date, :last_name, :first_name, :street_address, :street_address_2, :state, :city, :state, :postal_code,
               :phone, :collected, :payout, :facility_fee, :tickets_remaining, :status]

    fee = Money.from_numeric(offer.facility_fee.nil? ? 0 : offer.facility_fee)
    totals = {:payout=>Money.new(0), :facility_fee=>Money.new(0)}
    orders.select { |o| !o.nil? && o.paid? }.sort { |o1, o2| o2.created_at <=> o1.created_at }.each { |o|
      flex_pass = FlexPass.find_by_order_id(o.id)

      used = FlexPassPayment.find_all_by_flex_pass_id(flex_pass.id)
      if offer.flat_payout.blank? || offer.flat_payout == 0
        payout = Money.from_numeric(used.sum{|p| p.number_of_tickets} * offer.payout_per_ticket)
      else
        payout = Money.from_numeric(offer.flat_payout.nil? ? 0 : offer.flat_payout)
      end
      report << {:order_date=>Date.parse(o.created_at.to_s),
                 :last_name=>o.address.last_name,
                 :first_name=>o.address.first_name,
                 :street_address=>o.address.line1,
                 :street_address_2=>o.address.line2,
                 :state=>o.address.state,
                 :city=>o.address.city,
                 :state=>o.address.state,
                 :postal_code=>o.address.zipcode,
                 :phone=>o.address.phone,
                 :payout=>payout,
                 :collected=>Money.from_numeric(offer.price),
                 :facility_fee=>fee,
                 :tickets_remaining=>offer.number_of_tickets - used.sum { |p| p.number_of_tickets },
                 :status=>o.status
      }
      totals[:payout] += payout
      totals[:facility_fee] += fee

    }
    [headers, report, totals]
  end

  def build_production_sales_by_performance(production)
    ticket_classes = production.ticket_classes.sort { |t1, t2| t2.ticket_price <=> t1.ticket_price }
    total_tickets = Hash.new
    ticket_classes.each { |tc| total_tickets[tc.class_code] = 0 }
    total_tickets[:gross] = Money.new(0)
    total_tickets[:facility] = Money.new(0)
    total_tickets[:processing] = Money.new(0)
    total_tickets[:paid] = 0
    total_tickets[:holds] = 0

    report = Array.new
    # header row
    keys = [:performance_code, :performance_date, :performance_time]
    ticket_classes.each { |tc| keys << tc.class_code }
    keys += [:paid, :holds, :gross, :facility, :processing, :net]

    production.performances.sort { |x, y| (x.performance_date == y.performance_date) ?
        x.performance_time <=>y.performance_time :
        x.performance_date <=> y.performance_date
    }.each { |perf|
      paid_orders = perf.orders.select { |o| o.paid? }
      held_orders = perf.orders.select { |o| o.held? }
      paid_tickets = paid_orders.sum { |o| o.ticket_quantity }
      held_tickets = held_orders.sum { |o| o.ticket_quantity }
      gross = Money.from_numeric(paid_orders.sum { |o| o.total })
      ticketing_fee = Money.from_numeric(paid_orders.sum { |o| o.ticketing_fee })
      credit_card_processing_fee = Money.from_numeric(paid_orders.sum { |o| o.credit_card_processing_fee })
      total_tickets[:gross] += gross
      total_tickets[:facility] += ticketing_fee
      total_tickets[:processing] += credit_card_processing_fee
      total_tickets[:paid] += paid_tickets
      total_tickets[:holds] += held_tickets
      row = {:performance_code => perf.performance_code,
             :performance_date => perf.performance_date,
             :performance_time => perf.performance_time}
      ticket_classes.each { |tc|
        class_qty = paid_orders.sum { |o| o.ticket_quantity_by_class(tc.class_code) }
        total_tickets[tc.class_code] += class_qty
        row[tc.class_code] = class_qty
      }

      row[:paid] = paid_tickets
      row[:holds] = held_tickets
      row[:gross] = gross
      row[:facility] = ticketing_fee
      row[:processing] = credit_card_processing_fee
      row[:net] = gross - (ticketing_fee + credit_card_processing_fee)
      report << row

    }

    total_tickets[:net] = total_tickets[:gross] - (total_tickets[:facility] + total_tickets[:processing])

    [keys, report, total_tickets]

  end
end
