class Admin::AddressesController < Admin::ApplicationController
  # before_filter { |c| Authorization.current_user = c.current_user }

  filter_resource_access

  # GET /admin/addresses
  # GET /admin/addresses.xml
  def index
    @addresses = Address.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @addresses }
    end
  end

  # GET /admin/addresses/1
  # GET /admin/addresses/1.xml
  def show
    @visible_orders = @address.orders.select{|o| current_user.is_administrator? or current_user.is_box_office_user?|| current_user.theater_ids.include?(o.theater_id) }
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @address }
    end
  end

  # GET /admin/addresses/new
  # GET /admin/addresses/new.xml
  def new
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @address }
    end
  end

  # GET /admin/addresses/1/edit
  def edit
  end

  # POST /admin/addresses
  # POST /admin/addresses.xml
  def create
    match = @address.find_original
    if !match.nil? then
      match.update_from(@address)
      @address = match
      notice = "Merged with existing audience member"
    else
      notice = "Audience member successfully created."
    end
    respond_to do |format|
      if @address.save
        format.html {
          flash.keep
          redirect_to(admin_address_path(@address), :notice => notice)
        }
        format.xml  { render :xml => :admin_address, :status => :created, :location => @address }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @address.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /admin/addresses/1
  # PUT /admin/addresses/1.xml
  def update
    @address.update_attributes(params[:address])
  #  @address.address_tags = Array.new
  #  params[:address][:address_tags_attributes].each_pair {
  #      |k, v|
  #    @address.address_tags << AddressTag.new(v)
  #  }
    #@address.address_tags.build(params[:address][:address_tags_attributes])
#    @address.address_tags << params[:address][:address_tags_attributes]
    match = @address.find_original
    if !match.nil? then
      match.update_from(@address)
      @address = match
      notice = "Updated data merged with existing audience member"
    else
      notice = "Audience member was successfully updated."
    end
    respond_to do |format|
      if @address.save

        format.html {
          flash.keep
          redirect_to(:admin_address, :notice => notice)
        }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @address.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /admin/addresses/1
  # DELETE /admin/addresses/1.xml
  def destroy
    @address = Address.find(params[:id])
    @address.destroy

    respond_to do |format|
      format.html { redirect_to(admin_addresses_url) }
      format.xml  { head :ok }
    end
  end
end
