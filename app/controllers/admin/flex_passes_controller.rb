class Admin::FlexPassesController < Admin::ApplicationController
  prepend_before_filter :find_flex_pass

  def index
    @flex_passes = FlexPass.all
    render '/admin/scaffold/index'
  end

end
