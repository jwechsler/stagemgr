class CurrentUser::ApplicationController < ApplicationController
  before_action :require_login
end
