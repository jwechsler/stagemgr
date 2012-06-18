class Admin::ReportsController < Admin::ApplicationController
  include Admin::ReportsHelper
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
      @flex_pass_offers = @productions.select { |p| !p.flex_pass_offer.nil? }.map { |p| p.flex_pass_offer }
    else
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
    @production = Production.with_permissions_to(:read).find(params[:report][:production_id])
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
    @start_day = grab_from_date_select(:start_day, params[:report])
    @end_day = grab_from_date_select(:end_day, params[:report])
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
    minimum_attended = 0,required_theaters = nil,minimum_revenue = 0.0
    @start_day = grab_from_date_select(:from_day, params[:report])
    if params[:required_theaters].nil?
      required_theaters = []
    else
      required_theaters = params[:required_theaters].map{|t| t.to_i}
    end
    minimum_attended = params[:minimum_attended].to_i
    minimum_revenue = params[:minimum_revenue].to_i
    @headers, @report_data = build_telemarketing_dump(@start_day, minimum_attended, required_theaters, minimum_revenue)
    send_report_as_csv ('customer',@headers, @report_data)
  end

  def membership_usage
    days = [grab_from_date_select(:start_day, params[:report]),grab_from_date_select(:end_day, params[:report])]
    @start_day = days.min
    @end_day = days.max
    @headers, @report_data = build_membership_usage(@start_day, @end_day, params['download_csv'].nil?)
    if params['download_csv'].nil? then
      respond_to do |format|
        format.html
      end
    else
      send_report_as_csv('membership_usage', @headers, @report_data)
    end
  end

  def trg_dump
    @headers, @report_data = build_trg_dump
    if params['download_csv'].nil? then
      respond_to do |format|
        format.html
      end
    else
      send_report_as_csv('trg_data', @headers, @report_data)
    end
  end

  def fulfill_tickets
    @through_day = grab_from_date_select(:through_day, params[:report])
    @headers, @report_data = build_fulfill_labels(@through_day)
    send_report_as_csv('ticket_labels', @headers, @report_data)
  end

  def production_sales_by_performance

    @production = Production.find(params[:report][:production_id])
    @headers, @report_data = build_production_sales_by_performance(@production, !params['download_csv'].nil?)
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

  def send_report_as_csv(title, headers, data)
    csv_string = FasterCSV.generate do |csv|
      csv << headers
      data.each do |r|
        csv << headers.map { |h| tidy_output(r[h]) }
      end
    end
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
                :email=>a.email}
  end

  def address_hash_from_order(o)
    unless o.address.blank?
      address_hash(o.address)
    else
         {:last_name=>'',
            :first_name=>'',
            :street_address=>'',
            :street_address_2=>'',
            :state=>'',
            :city=>'',
            :state=>'',
            :postal_code=>'',
            :phone=>'',
            :email=>''}
    end

  end

  def build_fulfill_labels(through_date)
    orders = TicketOrder.order("performances.performance_date, productions.production_code, performances.performance_code, addresses.last_name").all(:include=>[:ticket_line_items, {:performance, :production}, :address],
                                                                    :conditions=>["orders.status = ? and performances.status = 'Active' and performances.performance_date <= ? and performances.performance_date >= ? and productions.status in (?)",
                                                                                  Order::PROCESSED, through_date, Date.today, Production.visible_statuses])
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
          attendance_code += ("%03d" % last24).reverse
          attendance_code += "A" if is_donor
          report << {:reserved_under=> "#{o.address.last_name}" + ((o.address.last_name.blank? || o.address.first_name.blank?) ? '' : ', ') + (o.address.first_name.blank? ? '' : o.address.first_name.first),
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

  def build_membership_usage(start_day, end_day, display_only = true)
    memberships = Membership.order(:member_since)
    report = Array.new
    sums = {:collected=>Money.new(0), :payout=>Money.new(0), :performances_attended=>0, :number_cycles=>0}
    headers = [:member_since, :last_name, :first_name]
    headers += [:street_address, :street_address_2, :state, :city, :state, :postal_code, :phone] unless display_only
    headers += [:status, :number_cycles, :collected, :performances_attended, :payout, :net_revenue, :avg_revenue_month, :avg_performances_month]
    memberships.each do |membership|
      unless membership.number_cycles_completed.nil? || membership.number_cycles_completed == 0 || membership.member_since > end_day || (membership.member_since + membership.number_cycles_completed.months) < start_day
        cutoff_max = [membership.next_billing_date, end_day].min
        cutoff_max = Date.civil(cutoff_max.year, cutoff_max.month, membership.next_billing_date.day)
        cutoff_min = [membership.member_since, start_day].max
        cutoff_min = Date.civil(cutoff_min.year, cutoff_min.month, membership.member_since.day)
        cycles_in_window = ((cutoff_max.year*12+cutoff_max.month)-(cutoff_min.year*12+cutoff_min.month))
        if cycles_in_window == 0
          cutoff_max = cutoff_min + 1.month
          cycles_in_window = 1
        end
        total_payout = Payment.sum(:amount, :conditions=>["type = 'MembershipPayment' and membership_id = ? and exists (select * from orders, performances where orders.id = payments.order_id and orders.performance_id = performances.id and performances.performance_date <= ? and performances.performance_date >= ?)", membership.id, cutoff_max, cutoff_min])
        num_attended = Payment.count(:conditions=>["type = 'MembershipPayment' and membership_id = ? and exists (select * from orders, performances where orders.id = payments.order_id and orders.performance_id = performances.id and performances.performance_date <= ? and performances.performance_date >= ?)", membership.id, cutoff_max, cutoff_min])
        avg_revenue_month = Money.from_numeric(0.0)
        avg_performances_month = 0.0
        avg_revenue_month = Money.from_numeric((membership.aggregate_amount-total_payout)/cycles_in_window)
        avg_performances_month = ((0.0 + num_attended)/cycles_in_window).round(1)
        aggregate_amount = membership.aggregate_amount.nil? ? 0.0 : membership.aggregate_amount

        report << {:member_since=>membership.member_since.strftime("%D"),
                   :last_name=>membership.membership_line_item.order.address.last_name,
                   :first_name=>membership.membership_line_item.order.address.first_name,
                   :status=>membership.status,
                   :number_cycles=>cycles_in_window,
                   :collected=>Money.from_numeric(aggregate_amount),
                   :performances_attended=>num_attended,
                   :payout=>Money.from_numeric(total_payout),
                   :net_revenue => Money.from_numeric(aggregate_amount-total_payout),
                   :avg_revenue_month=>avg_revenue_month,
                   :avg_performances_month=>avg_performances_month
        }.merge(address_hash_from_order(membership.membership_line_item.order))
        sums[:collected] += Money.from_numeric(aggregate_amount)
        sums[:payout] += Money.from_numeric(total_payout)
        sums[:performances_attended] += num_attended
        sums[:number_cycles] += cycles_in_window
      end
    end
    if sums[:number_cycles] > 0
      sums[:net_revenue] = sums[:collected] - sums[:payout]
      sums[:avg_revenue_month] = (sums[:net_revenue])/sums[:number_cycles]
      sums[:new_revenue] = sums[:collected] - sums[:payout]
      sums[:avg_performances_month] = ((0.0 + sums[:performances_attended]) / sums[:number_cycles]).round(1)
    end
    report << sums
    [headers, report]
  end


  def build_trg_dump
    orders = TicketOrder.order(:performance_id).includes(:address,:theater, {:performance, :production})
    report = Array.new
    headers = [:buyer_type, :year, :description, :first, :last, :full_name, :company, :email, :address1, :address2,
               :address3, :city, :state, :zip, :home_phone, :business_phone, :patron_id]
    orders.each do |order|

      buyer_type = case
        when order.paid_with_membership?
          'MEM'
        when order.theater.is_default?
          order.total == 0 ? 'CMP' : 'STB'
        else
          'REN'
      end

      season_tag = order.performance.production.season.to_i - 1
      season_text = "#{season_tag.to_s[2..3]}-#{order.performance.production.season[2..3]}"

      description = "#{season_text} #{buyer_type}: #{order.performance.production.name}"
      report << trg_hash(buyer_type, order.performance.production.season, description, order.address)

      description = "#{season_text} FULL: Building Attendee"
      report << trg_hash(buyer_type, order.performance.production.season, description, order.address)

      if order.theater.is_resident?
        description = "#{season_text} FULL: Resident Company Attendee"
        report << trg_hash(buyer_type, order.performance.production.season, description, order.address)
      end

      if order.theater.is_default?
        description = "#{season_text} FULL: #{order.theater.name} Attendee"
        report << trg_hash(buyer_type, order.performance.production.season, description, order.address)
      end


    end

    orders = MembershipOrder.includes(:address,[:membership_line_items,:membership])

    orders.each do |order|
      description = "#{order.membership.member_since.year} MEM: #{order.membership.membership_offer.name}"
      report << trg_hash('DNT', order.membership.member_since.year, description, order.address)
    end

    orders = DonationOrder.include(:address)

    orders.each do |order|
      description = "#{order.created_at.year} Donor"
      report << trg_hash('DNT', order.created_at.year, description, order.address)
    end

    [headers,report]

  end

  def build_telemarketing_dump(start_day, minimum_attended = 0,required_theaters = nil,minimum_revenue = 0.0)
    orders = TicketOrder.includes(:address).where("orders.status in (?) and orders.created_at >= ?",Order.attended_statuses, start_day)
    orders = orders.select {|o| required_theaters.include?(o.performance.production.theater_id)} unless (required_theaters.nil? || required_theaters.empty?)
    addresses = orders.map{|o| o.address}.uniq.select{|a| !a.nil? && a.productions_attended(start_day).size >= minimum_attended && a.revenue_collected(start_day) >= minimum_revenue}.sort{|a,b| a.last_name <=> b.last_name}

    report = Array.new
    headers = [:primary_theatre_attendee, :full_name, :phone, :email, :last_attended, :attended_in_period, :total_attended, :companies_attended_in_period, :total_companies_attended, :is_member, :is_flex_pass_holder, :production_history, :city, :state, :postal_code ]
    addresses.each do |address|
      all_prods = address.productions_attended
      primary_attendee = all_prods.map {|p| p.theater_id}.uniq.include?(1)
      requested_prods = address.productions_attended(start_day)
      prods = requested_prods.sort{|a,b| if b.opening_at.nil?
        false
      elsif a.opening_at.nil?
        true
      else
        b.opening_at <=> a.opening_at
      end
      }.map{|p| "#{p.name} [#{p.theater.name}]"}
      prodlist = prods.join(", ")
          report << address_hash(address).merge({:primary_theatre_attendee=>primary_attendee ? "*" : "",
                                                 :full_name=>address.full_name,
                                                 :last_attended=>address.last_attendance_date,
                                                 :attended_in_period => prods.size,
                                                 :total_attended => all_prods.size,
                                                 :companies_attended_in_period => requested_prods.map {|p| p.theater_id}.uniq.size,
                                                 :total_companies_attended => all_prods.map {|p| p.theater_id}.uniq.size,
                                                 :production_history=>prodlist,
                                                 :is_member=>address.is_current_member? ? "Y" : "N",
                                                 :is_flex_pass_holder=>address.is_current_flex_pass_holder? ? "Y" : "N"})
    end

    [headers, report]

  end

  def build_flexpass_sales(offer, display_only = true)
    orders = offer.flex_passes.map { |f| f.order }
    report = Array.new
    headers = [:order_date, :last_name, :first_name]
    headers += [:street_address, :street_address_2, :state, :city, :state, :postal_code, :phone] unless display_only
    headers += [:email] if permitted_to?(:view_email, :admin_addresses)
    headers += [:collected, :payout, :facility_fee, :tickets_remaining, :status]

    fee = Money.from_numeric(offer.facility_fee.nil? ? 0 : offer.facility_fee)
    totals = {:payout=>Money.new(0), :facility_fee=>Money.new(0), :display_class=>:report_summary_row}
    orders.select { |o| !o.nil? && o.paid? }.sort { |o1, o2| o2.created_at <=> o1.created_at }.each { |o|
      flex_pass = FlexPass.find_by_order_id(o.id)

      used = FlexPassPayment.find_all_by_flex_pass_id(flex_pass.id)
      if offer.flat_payout.blank? || offer.flat_payout == 0
        payout = Money.from_numeric(used.sum { |p| p.number_of_tickets } * offer.payout_per_ticket)
      else
        payout = Money.from_numeric(offer.flat_payout.nil? ? 0 : offer.flat_payout)
      end
      report << {:order_date=>Date.parse(o.created_at.to_s),
                 :payout=>payout,
                 :collected=>Money.from_numeric(offer.price),
                 :facility_fee=>fee,
                 :tickets_remaining=>offer.number_of_tickets - used.sum { |p| p.number_of_tickets },
                 :status=>o.status,
                 :display_class=>:report_detail_row}.merge(address_hash_from_order(o))
      totals[:payout] += payout
      totals[:facility_fee] += fee

    }
    report << totals
    [headers, report]

  end


  def build_production_sales_by_performance(productions, include_classes = true, perfs = nil)

    if productions.is_a?(Array)
      include_classes = false
    else
      productions = [productions]
    end
    keys = Array.new
    report = Array.new
    total_tickets = Hash.new
    total_tickets[:gross] = Money.new(0)
    total_tickets[:facility] = Money.new(0)
    total_tickets[:processing] = Money.new(0)
    total_tickets[:paid] = 0
    total_tickets[:holds] = 0
    total_tickets[:display_class] = :report_summary_row

    productions.sort! { |p1, p2| p1.name <=> p2.name }
    productions.each { |production|
      subtotal = Hash.new

      ticket_classes = production.ticket_classes.sort { |t1, t2| t2.ticket_price <=> t1.ticket_price }
      keys = [:performance_code, :performance_date, :performance_time]
      ticket_classes.each { |tc| keys << tc.class_code } if include_classes
      keys += [:paid, :holds, :max_ticket, :gross, :facility, :processing, :net]
      ticket_classes.each { |tc| total_tickets[tc.class_code] = 0 }
      subtotal[:gross] = Money.new(0)
      subtotal[:facility] = Money.new(0)
      subtotal[:processing] = Money.new(0)
      subtotal[:paid] = 0
      subtotal[:holds] = 0
      subtotal[:display_class] = :report_summary_row
      subtotal[:performance_code] = production.production_code
      # header row

      use_performances = perfs.nil? ? production.performances : perfs.select { |p| p.production.id == production.id }


      use_performances.sort { |x, y| (x.performance_date == y.performance_date) ?
          x.performance_time <=>y.performance_time :
          x.performance_date <=> y.performance_date
      }.each { |perf|
        paid_orders = perf.orders.select { |o| o.paid? }
        held_orders = perf.orders.select { |o| o.held? }
        paid_tickets = paid_orders.sum { |o| o.ticket_quantity }
        held_tickets = held_orders.sum { |o| o.ticket_quantity }
        max_ticket_price = perf.ticket_class_allocations.select{|tca| tca.available? }.max_by{|tca| tca.ticket_class.ticket_price}.ticket_class.ticket_price
        gross = Money.from_numeric(paid_orders.sum { |o| o.total })
        ticketing_fee = Money.from_numeric(paid_orders.sum { |o| o.ticketing_fee })
        credit_card_processing_fee = Money.from_numeric(paid_orders.sum { |o| o.credit_card_processing_fee })
        subtotal[:gross] += gross
        subtotal[:facility] += ticketing_fee
        subtotal[:processing] += credit_card_processing_fee
        subtotal[:paid] += paid_tickets
        subtotal[:holds] += held_tickets
        row = {:performance_code => perf.performance_code,
               :performance_date => perf.performance_date,
               :performance_time => perf.performance_time,
               :display_class => :report_detail_row,
               :max_ticket => Money.from_numeric(max_ticket_price)}
        if include_classes then

          ticket_classes.each { |tc|
            class_qty = paid_orders.sum { |o| o.ticket_quantity_by_class(tc.class_code) }
            total_tickets[tc.class_code] += class_qty
            row[tc.class_code] = class_qty
          }

        end

        row[:paid] = paid_tickets
        row[:holds] = held_tickets
        row[:gross] = gross
        row[:facility] = ticketing_fee
        row[:processing] = credit_card_processing_fee
        row[:net] = gross - (ticketing_fee + credit_card_processing_fee)
        report << row

      }
      subtotal[:net] = subtotal[:gross] - (subtotal[:facility] + subtotal[:processing])

      report << subtotal
      total_tickets[:gross] += subtotal[:gross]
      total_tickets[:facility] += subtotal[:facility]
      total_tickets[:processing] += subtotal[:processing]
      total_tickets[:paid] += subtotal[:paid]
      total_tickets[:holds] += subtotal[:holds]

    }

    total_tickets[:net] = total_tickets[:gross] - (total_tickets[:facility] + total_tickets[:processing])
    total_tickets[:performance_code] = "TOTAL"
    if productions.size > 1
      report << total_tickets
    end

    [keys, report]
  end


  def build_weekly_box_office(week_ending)

    performances = Performance.where("performance_date >= ? and performance_date <= ?",
                                     week_ending.beginning_of_week, week_ending.end_of_week)
    productions = performances.map { |p| p.production }.uniq
    build_production_sales_by_performance(productions, false, performances)
  end

  def grab_from_date_select(field_name, params)
    Date.new(params["#{field_name.to_s}(1i)"].to_i,
             params["#{field_name.to_s}(2i)"].to_i,
             params["#{field_name.to_s}(3i)"].to_i)
  end

  def columns_for_orders(build_for_dumpfile)
    keys = [:order_date]
    keys += [:id, :first_name, :last_name, :street_address, :street_address_2, :city, :state, :postal_code, :phone] if build_for_dumpfile
    keys += [:email] if (build_for_dumpfile && permitted_to?(:view_email, :admin_addresses))
    keys += [:performance_code, :special_offer_code, :status, :description] if build_for_dumpfile
    keys
  end

  def create_hash_from_order_fields(order)
    row = Hash.new
    row[:order_date] = order.created_at.to_formatted_s(:long) unless order.created_at.nil?
    row[:id] = order.id
    row = row.merge(address_hash_from_order(order))
    row[:performance_code] = order.performance.performance_code if !order.performance.blank?
    row[:special_offer_code] = order.special_offer_code_used
    row[:status] = order.status
    row[:description] = order.description
    row[:order_total] = order.total
    row[:num_tickets]  = order.total_ticket_quantity
    row
  end

  def build_daily_box_office_receipts(start_day, end_day, build_for_dumpfile = false)

    report = Array.new
    day_total = Hash.new
    zero_dollars = Money.new(0)
    keys = columns_for_orders(build_for_dumpfile)
    payment_types = [CashPayment.to_s, CreditCardPayment.to_s, PriceOverridePayment.to_s, FlexPassPayment.to_s, MembershipPayment.to_s]
    keys += payment_types
    current_date = start_day - 1.week
    payments = Payment.order("processed_on").where("processed_on >=:start_day and processed_on < :end_day", {:start_day=>start_day, :end_day=>(end_day + 1.day)})
    payments.each { |p|
      c_day = p.processed_on
      if c_day != current_date then
        current_date = c_day
        report << day_total unless day_total.empty?
        day_total = Hash.new
        day_total[:order_date] = c_day
        day_total[:display_class] = :report_summary_row
        payment_types.each { |t| day_total[t] = Money.new(0) }
      end

      amt = p.amount.nil? ? zero_dollars : Money.from_numeric(p.amount)
      day_total[p.class.to_s] += amt if payment_types.include?(p.class.to_s)


      if build_for_dumpfile then
        row = create_hash_from_order_fields(p.order)
        row[p.class.to_s] = amt
        row[:display_class] = :report_detail_row
        report << row
      end


    }
    report << day_total
    [keys, report]
  end

  def build_donations_dump(start_day, end_day, build_for_dumpfile = false)
    donations = Order.all(:include=>[:address, :donation_line_items, :payments], :conditions=>["orders.status in (?) and line_items.type = 'DonationLineItem' and payments.processed_on >= ? and payments.processed_on <= ?", Order::PROCESSED, start_day, end_day])
    report = Array.new
    keys = columns_for_orders(true) + [:total]
    Order.transaction do
      donations.each { |o|
        total = o.total
        if total > 0
          row = create_hash_from_order_fields(o)
          row[:total] = o.total
          report << row
        end
        o.transition_to!(Order::FULFILLED)
      }

    end
    [keys, report]
  end

  def build_order_dump(production)
    report = Array.new
    keys = columns_for_orders(true)
    keys += [:order_total, :num_tickets]
    production.performances.each { |performance|
      orders = TicketOrder.joins(:ticket_line_items).where("performance_id = :performance_id", {:performance_id=>performance.id})

      orders.each { |o|
        if o.attended? then
          row = create_hash_from_order_fields(o)
          report << row
        end
      }
    }
    [keys, report]
  end

end
