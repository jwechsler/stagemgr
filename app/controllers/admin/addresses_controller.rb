class Admin::AddressesController < Admin::ApplicationController
  load_and_authorize_resource

  autocomplete :address_tag,:tag_label

  # GET /admin/addresses
  # GET /admin/addresses.xml
  def index
    @addresses = Address.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @addresses }
      format.json { render json: AddressesDatatable.new(view_context) }
    end
  end

  # GET /admin/addresses/1
  # GET /admin/addresses/1.xml
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.json  {
        params.permit!
        render json: AddressesOrdersDatatable.new(params, view_context: view_context, current_user: current_user, address: @address)
      }
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
    @address.update_attributes(address_params)
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

  def autocomplete_address
    cleaned_name, first_name, middle_name, last_name, first_name_2 = Address.parse_name(params[:term])
    last_name = first_name if last_name.blank?
    # val = params[:q].gsub(Address::SEARCHABLE_REGEXP,'').upcase

    #addresses = Address.where("search_name like :search_expr and id in (select address_id from orders)", {:search_expr=>'%' + val + '%'}).limit(10).order(
    #    'last_name', 'first_name', 'id');
    unless first_name.blank? || (last_name == first_name)
      addresses = Address.where("((first_name like ?) or (first_name like ?)) and last_name like ?",
        "#{first_name}%", "#{first_name_2.blank? ? '-----' : first_name_2}%",
        "#{last_name}%").includes({:orders=>{:performance=>:production}}).order("addresses.last_name, addresses.first_name, addresses.id").limit(15)
    else
      addresses = Address.where("first_name like ? or last_name like ?", last_name+'%', last_name+'%').includes({:orders=>{:performance=>:production}}).order("addresses.last_name, addresses.first_name, addresses.id").limit(15)
    end
    if addresses.nil?
      render :json=>Array.new
    else
      render :json => addresses.map { |a|
        value = a.full_name
        member_code = a.is_current_member? ? a.current_membership.member_code : nil
        tags = current_user.allowed_tags(a.address_tags).map {|t|
          "<div class=\"small-6 columns quick-lookup-history label\">#{t.tag_label}</div><div class=\"small-6 columns quick-lookup-history\">#{t.tag_value}</div>"
          }.join(" ")
        label = a.full_name
        label += " [MEMBER]" unless member_code.nil?
        label += " #{a.line1} #{a.city} #{a.zipcode}" unless a.line1.blank?
        label += " #{a.email}" unless a.email.blank?
        attended = a.productions.uniq.sort {|a,b| b.closing_at <=> a.closing_at}[0..9].map{|p| "<div class=\"small-6 columns quick-lookup-history\">#{p.name}</div>" }.join(' ')
        { :id => a.id,
          :label=>label,
          :value=>a.full_name,
          :full_name => a.full_name,
          :email => a.email,
          :line1=>a.line1,
          :line2=>a.line2,
          :city=>a.city,
          :state=>a.state,
          :zipcode=>a.zipcode,
          :phone=>a.phone,
          :member_code=>member_code,
          :tags=>tags,
          :attended=>attended
        }

      }
    end
  end

  def autocomplete_tag
    #tags = AddressTag.order(:tag_label).select('tag_label').where('tag_label like ?', "#{params[:term]}%").uniq
    #render :json => tags.map do |tag|
    #  { :id=>tag.tag_label, :label=>tag.tag_label, :value=>tag.tag_label }
    #end
    render :json=>AddressTag.order(:tag_label).select('DISTINCT tag_label');
  end

  private
  def address_params
    params.require(:address).permit(:full_name, :line1, :line2, :city, :state, :zipcode, :email, :phone, :street_number, :address_tags_attributes, :_destroy)
  end

end
