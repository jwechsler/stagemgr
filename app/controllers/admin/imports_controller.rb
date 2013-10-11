class Admin::ImportsController < Admin::ApplicationController
  filter_access_to :all
  include ProductionsHelper

  def index
    @imports = FileStore.where("worker = ? and user_id = ?", FileStore::IMPORT, current_user.id)
    @trg_basic_import = FileStore.new
    @trg_basic_import.format = FileStore::TRG_LIST_IMPORT_FORMAT
    @productions = productions_visible_to_operations
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @theaters }
    end

  end

  def create
    @trg_basic_import = FileStore.create(params[:file_store])
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



end
