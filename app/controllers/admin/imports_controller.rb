class Admin::ImportsController < Admin::ApplicationController
  skip_authorize_resource
  include ProductionsHelper

  rescue_from ActionController::ParameterMissing do |exception|
    flash[:error] = "You must choose a file to import"
    redirect_to action: :index
  end

  def index
    authorize! :read, :import_operations
    @imports = FileStore.where("worker = ? and user_id = ?", FileStore::IMPORT, current_user.id)
    @trg_basic_import = FileStore.new
    @trg_basic_import.format = FileStore::TRG_LIST_IMPORT_FORMAT
    @card_basic_import = FileStore.new
    @card_basic_import.format = FileStore::MAILING_CARD_IMPORT_FORMAT
    @card_external_import = FileStore.new
    @card_external_import.format = FileStore::EXTERNAL_CONTACT_FORMAT
    @bulk_orders_import = FileStore.new
    @bulk_orders_import.format = FileStore::BULK_ORDER_FORMAT
    @bulk_flex_pass_orders_import = FileStore.new
    @donor_import = FileStore.new
    @donor_import.format = FileStore::DONATION_LEVELS_IMPORT_FORMAT
    @productions = productions_visible_to_operations
    @theaters = Theater.all.accessible_by(current_ability).where(status: Theater::ACTIVE)
    @payment_types = ExternalPaymentType.all.order(:display_name)
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @theaters }
    end
  end

  def create
    @trg_basic_import = FileStore.create(file_store_params)
    @production = Production.find(params[:production][:production_id]) unless params[:production][:production_id].blank?
    @trg_basic_import.user = current_user
    @trg_basic_import.format = FileStore::TRG_LIST_IMPORT_FORMAT
    @trg_basic_import.worker = FileStore::IMPORT
    @trg_basic_import.notes = "#{(@production.nil? ? '' : @production.name) + ' '}Attendees"
    if @trg_basic_import.is_trg_list_format? && @trg_basic_import.save
      Resque.enqueue(TrgImport, @trg_basic_import.id, @production.nil? ? 0 : @production.id)
      flash[:notice] = 'Your list is importing'
    else
      flash[:error] = 'Invalid format'
    end
    redirect_back_or_default admin_imports_path

  end

  def mailing_cards
    @card_basic_import = FileStore.create(file_store_params)
    @production = Production.find(params[:production][:production_id])
    @card_basic_import.user = current_user
    @card_basic_import.format = FileStore::MAILING_CARD_IMPORT_FORMAT
    @card_basic_import.worker = FileStore::IMPORT
    @card_basic_import.notes = "#{@production.name} Mailing List signups"
    if @card_basic_import.is_mailing_card_format? && @card_basic_import.save
      Resque.enqueue(MailingCardImport, @card_basic_import.id, @production.nil? ? 0 : @production.id)
      flash[:notice] = 'Your list is importing'
    else
      flash[:error] = 'Invalid format'
    end
    redirect_back_or_default admin_imports_path

  end

  def external_contacts
    @card_external_import = FileStore.create(file_store_params)
    @theater = Theater.find(params[:theater][:theater_id])
    @card_external_import.user = current_user
    @card_external_import.format = FileStore::EXTERNAL_CONTACT_FORMAT
    @card_external_import.worker = FileStore::IMPORT
    @card_external_import.notes = "#{@theater.name} contact import"
    if @card_external_import.save then
      Resque.enqueue(ExternalAddressesImport, @card_external_import.id, @theater.id)
      flash[:notice] = 'Your contact list is importing'
    else
      flash[:error] = 'Invalid format'
    end
    redirect_back_or_default admin_imports_path
  end

  def bulk_orders
    @bulk_orders_import = FileStore.create(file_store_params)
    @theater = Theater.find(params[:theater][:theater_id])
    @bulk_orders_import.user = current_user
    @bulk_orders_import.format = FileStore::BULK_ORDER_FORMAT
    @bulk_orders_import.worker = FileStore::IMPORT
    @bulk_orders_import.notes = "Order import"
    if @bulk_orders_import.save then
      Resque.enqueue(BulkOrderImport, @bulk_orders_import.id, @theater.id, params[:payment_type][:payment_type_id], params[:add_to_email_list])
      flash[:notice] = 'Your orders are being imported.'
    else
      flash[:error] = 'Invalid format'
    end
    redirect_back_or_default admin_imports_path
  end

  def bulk_flex_pass_orders
    @bulk_flex_pass_orders_import = FileStore.create(file_store_params)
    @theater = Theater.find(params[:theater][:theater_id])
    @bulk_flex_pass_orders_import.user = current_user
    @bulk_flex_pass_orders_import.worker = FileStore::IMPORT
    @bulk_flex_pass_orders_import.notes = "Flex Pass order import"
    if @bulk_flex_pass_orders_import.save then
      Resque.enqueue(BulkFlexOrderImport, @bulk_flex_pass_orders_import.id, @theater.id, params[:payment_type][:payment_type_id])
      flash[:notice] = 'Your flex passes are being created'
    else
      flash[:error] = 'Invalid format'
    end
    redirect_back_or_default admin_imports_path
  end

  def donation_levels
    @donation_levels_import = FileStore.create(file_store_params)
    @donation_levels_import.user = current_user
    @donation_levels_import.worker = FileStore::IMPORT
    @donation_levels_import.notes = "Donation Level Import"
    if @donation_levels_import.save then
      Resque.enqueue(LglDonorImport, @donation_levels_import.id)
      flash[:notice] = 'Your current and previous fiscal year donation tiers are being imported'
    else
      flash[:error] = 'Invalid format'
    end
    redirect_back_or_default admin_imports_path
  end


  private
  def file_store_params
    params.require(:file_store).permit!
  end

end
