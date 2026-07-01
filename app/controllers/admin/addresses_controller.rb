class Admin::AddressesController < Admin::ApplicationController
  load_and_authorize_resource

  autocomplete :address_tag, :tag_label

  respond_to :html, :json

  # GET /admin/addresses
  # GET /admin/addresses.xml
  def index
    respond_to do |format|
      format.html # index.html.erb
      format.json do
        params.permit!
        render json: AddressDatatable.new(params, current_user: current_user)
      end
    end
  end

  # GET /admin/addresses/1
  # GET /admin/addresses/1.xml
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.json do
        params.permit!
        render json: AddressesOrdersDatatable.new(params, current_user: current_user, address: @address)
      end
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
  def edit; end

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
        format.html do
          flash.keep
          redirect_to(admin_address_path(@address), :success => notice)
        end
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
    @address.update(address_params)
    #  @address.address_tags = Array.new
    #  params[:address][:address_tags_attributes].each_pair {
    #      |k, v|
    #    @address.address_tags << AddressTag.new(v)
    #  }
    # @address.address_tags.build(params[:address][:address_tags_attributes])
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

        format.html do
          flash.keep
          redirect_to(:admin_address, :success => notice)
        end
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

  def merge_selected
    ids = params[:ids].sort { |a, b| a.to_i <=> b.to_i }
    address = Address.find(ids[0])
    ids.drop(1).each do |id|
      address2 = Address.find(id)
      address.merge_and_purge(address2)
    end
    render json: { result: true }
  rescue => e
    Rails.logger.error("Merge failed: #{e.message}\n#{e.backtrace.join("\n")}")
    render json: { result: false, error: e.message }, status: :unprocessable_entity
  end

  def autocomplete_address
    _, first_name, last_name = Address.parse_name(params[:term])
    last_name = first_name if last_name.blank?
    first_name = "" if first_name.nil?
    # val = params[:q].gsub(Address::SEARCHABLE_REGEXP,'').upcase

    # addresses = Address.where("search_name like :search_expr and id in (select address_id from orders)", {:search_expr=>'%' + val + '%'}).limit(10).order(
    #    'last_name', 'first_name', 'id');
    if first_name.blank? || last_name.eql?(first_name)
      Rails.logger.debug("**** CASE 2 last_name = #{last_name} and first_name = #{first_name}")

      if last_name.eql?(first_name)
        addresses = Address.where("search_name like ? or last_first_name like ?", (last_name + '%').upcase,
                                  (last_name + '%').upcase).order("addresses.last_name, addresses.first_name, addresses.id").limit(7)
      else
        addresses = Address.where("search_name like ? or last_first_name like ?", (first_name + last_name + '%').upcase,
                                  (last_name + first_name + '%').upcase).order("addresses.last_name, addresses.first_name, addresses.id").limit(7)
      end
    else
      addresses = Address.where("(first_name like ?) AND (last_name like ?)",
                                "#{first_name}%",
                                "#{last_name}%").order("addresses.last_name, addresses.first_name, addresses.id").limit(15)
    end
    if addresses.nil?
      render :json => []
    else
      render :json => addresses.to_a.uniq { |a| [a.first_name, a.last_name, a.email] }.map { |a|
        a.full_name
        member_code = a.is_current_member? ? a.current_membership.member_code : nil
        # tags = current_user.allowed_tags(a.address_tags).map {|t|
        #  "<div class=\"small-6 columns quick-lookup-history label\">#{t.tag_label}</div><div class=\"small-6 columns quick-lookup-history\">#{t.tag_value}</div>"
        #  }.join(" ")
        label = a.full_name
        label += " [MEMBER]" unless member_code.nil?
        label += " #{a.line1} #{a.city} #{a.zipcode}" if a.line1.present?
        label += " #{a.email}" if a.email.present?
        attended = a.productions.uniq.sort { |a, b|
          b.closing_at <=> a.closing_at
        }[0..9].map { |p| "<div class=\"small-6 columns quick-lookup-history\">#{p.name}</div>" }.join(' ')
        { :id => a.id,
          :label => label,
          :value => a.full_name,
          :full_name => a.full_name,
          :email => a.email,
          :line1 => a.line1,
          :line2 => a.line2,
          :city => a.city,
          :state => a.state,
          :zipcode => a.zipcode,
          :phone => a.phone,
          :member_code => member_code,
          :tags => [],
          :attended => attended }
      }
    end
  end

  def autocomplete_tag
    # tags = AddressTag.order(:tag_label).select('tag_label').where('tag_label like ?', "#{params[:term]}%").uniq
    # render :json => tags.map do |tag|
    #  { :id=>tag.tag_label, :label=>tag.tag_label, :value=>tag.tag_label }
    # end
    tags = AddressTag.order(:tag_label).select('tag_label').where("tag_label like :tl", tl: "#{params[:term]}%").uniq
    render :json => tags.map { |t| t.tag_label }
  end

  private

  def address_params
    params.require(:address).permit(:full_name, :line1, :line2, :city, :state, :zipcode, :email, :phone, :street_number, :address_tags_attributes, :_destroy, :vip, :placeholder, :photo,
                                    address_tags_attributes: [:tag_label, :theater_id, :tag_value, :_destroy, :id])
  end
end
