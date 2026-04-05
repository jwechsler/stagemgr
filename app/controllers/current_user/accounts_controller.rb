class CurrentUser::AccountsController < CurrentUser::ApplicationController
  def show
    @user = current_user
    @rate_of_sales = RateOfSale.where(day_of_sale: 7.days.ago.to_date..Date.today, production: @user.allowed_productions)
      .includes(:production)
      .order(:day_of_sale, 'productions.name')
    @gross_sales_data = @rate_of_sales.group_by(&:production).map do |production, sales|
      {
        name: production.name,
        data: sales.group_by(&:day_of_sale).map { |day, sales_for_day| [day.strftime('%Y-%m-%d'), 
          sales_for_day.sum(&:gross_sales) - sales_for_day.sum(&:processing_fees)] }.to_h
      }
    end
    # Aggregate sales data by theater for all dates
    @theater_sales_data = @rate_of_sales.group_by { |rate_of_sale| rate_of_sale.production.theater }.map do |theater, sales|
      {
        name: theater.name,
        data: sales.group_by(&:theater).map { |theater, sales_for_day| 
          [theater.name, sales_for_day.sum(&:gross_sales)]}.to_h,
        producing: theater.producing?,
        total_tickets: sales.sum(&:total_single_tickets),
        total_comps: sales.sum(&:total_complimentary_tickets),
        total_gross_sales: sales.sum(&:gross_sales),
        total_processing_fee: sales.sum(&:processing_fees)
      }
    end.sort_by { |t| -t[:total_gross_sales] }

    unless current_user.is_theater_user?
      @gross_sales_data = @rate_of_sales.select{|sales_data| sales_data.production.theater.producing? }.group_by(&:production).map do |production, sales|
        {
          name: production.name,
          data: sales.group_by(&:day_of_sale).map { |day, sales_for_day| [day.strftime('%Y-%m-%d'), sales_for_day.sum(&:gross_sales)] }.to_h
        }
      end
      @rate_of_sales = @rate_of_sales.select{|sale| sale.production.theater.producing?}
    end

    # Weekly sales chart data — all historical weeks up through last Sunday
    last_sunday = Date.today.beginning_of_week(:monday) - 1.day
    currently_producing = @user.allowed_productions
      .where(status: [Production::ACTIVE, Production::PRIVATE])
      .where('closing_at IS NULL OR closing_at >= ?', 30.days.ago.to_date)
    weekly_raw = RateOfSale
      .where(production: currently_producing)
      .where('day_of_sale <= ?', last_sunday)
    unless current_user.is_theater_user?
      weekly_raw = weekly_raw.joins(production: :theater)
        .where(theaters: { theater_class: [Theater::DEFAULT, Theater::COPRO] })
    end
    @weekly_sales_data = weekly_raw
      .includes(:production)
      .group_by(&:production)
      .map do |production, sales|
        presale_cutoff = production.first_preview_at ? (production.first_preview_at - 2.weeks).beginning_of_week(:monday) : nil
        pre_sales, weekly_sales = if presale_cutoff
          sales.partition { |s| s.day_of_sale < presale_cutoff }
        else
          [[], sales]
        end
        data = {}
        if pre_sales.any?
          data["pre-#{presale_cutoff.strftime('%-m/%d')}"] =
            pre_sales.sum(&:gross_sales) - pre_sales.sum(&:processing_fees)
        end
        weekly_sales
          .group_by { |s| s.day_of_sale.beginning_of_week(:monday) }
          .sort_by(&:first)
          .each do |week_start, week_data|
            data[week_start.strftime('%-m/%d')] =
              week_data.sum(&:gross_sales) - week_data.sum(&:processing_fees)
          end
        { name: production.name, data: data }
      end

    if current_user.is_theater_user?
      @house_counts = HouseCount.joins(performance: :production)
                         .where(performances: {
                            performance_date: Date.today..(Date.today + 30.days),
                            production: @user.allowed_productions
                         }).limit(14*@user.allowed_productions.count).order('performances.performance_date, performances.performance_code')
    else
      @house_counts = HouseCount.joins(performance: :production)
                         .where(performances: {
                            performance_date: Date.today..(Date.today + 7.days),
                            production: @user.allowed_productions
                         }).order('performances.performance_date, performances.performance_code')
    end
  end

  def edit
    @user = current_user
  end

  def update
    @user = current_user # makes our views "cleaner" and more consistent
    if @user.update(user_params[:user])
      flash[:notice] = "Account updated!"
      redirect_to current_user_account_url
    else
      render :action => :edit
    end
  end

  def user_params
    params.permit(user:[:email,:password,:status,:is_administrator,:is_box_office_user, :theater_ids=>[]])
  end
end
