class CurrentUser::ApplicationController < ApplicationController
  append_before_filter :require_login
end
