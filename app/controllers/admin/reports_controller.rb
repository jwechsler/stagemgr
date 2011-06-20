class Admin::ReportsController < Admin::ApplicationController
  # GET /admin/reports
  # GET /admin/reports.xml
  def index

    @productions = Production.with_permissions_to(:read).where(current_user.is_theater_user? ? "1=1" : "status != 'Inactive' and exists (select * from theaters where theaters.status != 'Inactive' and theaters.id = productions.theater_id)")
    if current_user.is_theater_user? then
      @productions.sort! { |p1, p2| p2.press_opening_at <=>p1.press_opening_at }
    else
      @productions.sort! { |p1, p2| p1.name <=> p2.name }
    end
    respond_to do |format|
      format.html # index.html.erb
    end
  end

  # GET /admin/reports/1
  # GET /admin/reports/1.xml
  def show
    @admin_report = Admin::Report.find(params[:id])

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

  def production_sales_by_performance

    @production = Production.find(params[:report][:production_id])
    @report_data = build_production_sales_by_performance(@production)

    respond_to do |format|
      format.html
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

  private
  def build_production_sales_by_performance(production)
    ticket_classes = production.ticket_classes.sort { |t1, t2| t2.ticket_price <=> t1.ticket_price }
    total_tickets = Hash.new
    ticket_classes.each { |tc| total_tickets[tc.class_code] = 0 }
    total_tickets[:gross] = BigDecimal.new(0,2)
    total_tickets[:facility] = BigDecimal.new(0,2)
    total_tickets[:processing] = BigDecimal.new(0,2)
    total_tickets[:paid] = 0
    total_tickets[:holds] = 0

    report = Array.new
    # header row
    keys = [:performance_code, :performance_date, :performance_time]
    ticket_classes.each {|tc| keys << tc.class_code}
    keys += [:paid, :holds, :gross, :facility, :processing, :net]

    production.performances.sort { |x, y| (x.performance_date == y.performance_date) ?
        x.performance_time <=>y.performance_time :
        x.performance_date <=> y.performance_date
    }.each { |perf|
      paid_orders = perf.orders.select { |o| o.paid? }
      held_orders = perf.orders.select { |o| o.held? }
      paid_tickets = BigDecimal.new(paid_orders.sum { |o| o.ticket_quantity }, 2)
      held_tickets = BigDecimal.new(held_orders.sum { |o| o.ticket_quantity }, 2)
      gross = BigDecimal.new(paid_orders.sum { |o| o.total },2)
      ticketing_fee = BigDecimal.new(paid_orders.sum { |o| o.ticketing_fee })
      credit_card_processing_fee = BigDecimal.new(paid_orders.sum { |o| o.credit_card_processing_fee })
      total_tickets[:gross] += gross
      total_tickets[:facility] += ticketing_fee
      total_tickets[:processing] += credit_card_processing_fee
      total_tickets[:paid] += paid_tickets
      total_tickets[:holds] += held_tickets

      row = {:performance_code => perf.performance_code,
                 :performance_date => perf.performance_date,
                 :performance_time => perf.performance_time }
      ticket_classes.each {|tc|
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

    total_tickets[:gross] = total_gross
    total_tickets[:faciliity] = total_facility
    total_tickets[:processing] = total_processing_fee
    total_tickets[:net] = total_tickets[:gross] - (total_tickets[:facility] + total_tickets[:processing])

    [keys, report, total_tickets]

  end
end
