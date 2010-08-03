class Admin::FlexPassesController < Admin::ApplicationController
  def index
    @flex_passes = FlexPass.all
    render '/admin/scaffold/index'
  end
end
