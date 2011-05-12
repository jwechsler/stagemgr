class Admin::FlexPassesController < Admin::ApplicationController
  prepend_before_filter :find_flex_pass

  def index
    @flex_passes = FlexPass.all
    render '/admin/flex_pass_offers/index'
  end

  def edit
    @flex_pass_offer = @flex_pass
    render '/admin/flex_pass_offers/edit'
  end

  private
    def find_flex_pass
    @flex_pass = FlexPass.find(params[:id])
  end
end
