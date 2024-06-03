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
    end

    unless current_user.is_theater_user?
      @gross_sales_data = @rate_of_sales.select{|sales_data| sales_data.production.theater.producing? }.group_by(&:production).map do |production, sales|
        {
          name: production.name,
          data: sales.group_by(&:day_of_sale).map { |day, sales_for_day| [day.strftime('%Y-%m-%d'), sales_for_day.sum(&:gross_sales)] }.to_h
        }
      end
      @rate_of_sales = @rate_of_sales.select{|sale| sale.production.theater.producing?}
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
