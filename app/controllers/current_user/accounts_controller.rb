class CurrentUser::AccountsController < CurrentUser::ApplicationController
  def show
    @user = current_user
    @rate_of_sales = RateOfSale.where(day_of_sale: 7.days.ago.to_date..Date.today, production: current_user.allowed_productions)
      .includes(:production)
      .order(:day_of_sale, 'productions.name')
    @gross_sales_data = @rate_of_sales.group_by(&:production).map do |production, sales|
      {
        name: production.name,
        data: sales.group_by(&:day_of_sale).map { |day, sales_for_day| [day.strftime('%Y-%m-%d'), sales_for_day.sum(&:gross_sales)] }.to_h
      }
    end
    @rate_of_sales = nil
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
