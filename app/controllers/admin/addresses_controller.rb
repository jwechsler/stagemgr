class Admin::AddressesController < ApplicationController
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
    @address = Address.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @address }
    end
  end

  # GET /admin/addresses/new
  # GET /admin/addresses/new.xml
  def new
    @address = Address.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @address }
    end
  end

  # GET /admin/addresses/1/edit
  def edit
    @address = Address.find(params[:id])
  end

  # POST /admin/addresses
  # POST /admin/addresses.xml
  def create
    @address = Address.new(params[:address])

    respond_to do |format|
      if @address.save
        format.html { redirect_to(:admin_address, :notice => 'Address was successfully created.') }
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
    @address = Address.find(params[:id])

    respond_to do |format|
      if @address.update_attributes(params[:admin_address])
        format.html { redirect_to(:admin_address, :notice => 'Address was successfully updated.') }
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
