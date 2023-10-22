class CurrentUser::AccountsController < CurrentUser::ApplicationController
  def show
    @user = current_user
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
