class Admin::TheatersController < Admin::ApplicationController
  include ReturnsToOrigin

  before_action :remove_empty_logo
  load_and_authorize_resource except: %i[autocomplete_tag search]

  before_action :find_context, only: :show

  respond_to :html, :json

  def autocomplete_tag
    term = params[:term].to_s
    names = TheaterTag.where('name LIKE ?', "#{term}%")
                      .order(:name).limit(20).pluck(:name).uniq
    render json: names
  end

  # Shared theater multi-picker typeahead (analysis comparison sets and other
  # theater pickers). Any logged-in admin user may search; the result set is
  # every theater, and callers narrow what the user may actually use.
  def search
    authorize! :read, Theater
    query = params[:q].to_s.strip
    return render(json: []) if query.blank?

    q = "%#{query.downcase}%"
    name_matches = Theater.where('LOWER(theaters.name) LIKE ?', q).limit(20)
    tag_matches  = Theater.joins(:theater_tags)
                          .where('LOWER(theater_tags.name) LIKE ?', q)
                          .distinct
                          .limit(20)

    seen_ids = {}
    results = []

    name_matches.order(:name).each do |t|
      next if seen_ids[t.id]

      seen_ids[t.id] = true
      results << { id: t.id, label: t.name, match_kind: 'name' }
    end

    # Also surface tag-keyed group entries (one row per matching tag), so the
    # operator can pick "every theater tagged X" in one click.
    matching_tags = TheaterTag.where('LOWER(name) LIKE ?', q).order(:name)
    seen_tag_keys = {}
    matching_tags.each do |tag|
      key = tag.name.to_s.downcase
      next if key.blank? || seen_tag_keys[key]

      seen_tag_keys[key] = true
      tag_theaters = Theater.tagged_with(tag.name).order(:name).pluck(:id, :name)
      next if tag_theaters.empty?

      results << {
        group_key: "tag:#{tag.name}",
        label: "All theaters tagged #{tag.name}",
        theaters: tag_theaters.map { |id, name| { id: id, name: name } }
      }
    end

    tag_matches.order(:name).each do |t|
      next if seen_ids[t.id]

      seen_ids[t.id] = true
      results << { id: t.id, label: t.name, match_kind: 'tag' }
    end

    render json: results
  end

  def index
    @theaters = @theaters.sort_by { |t| [t.status, t.theater_class, t.name] }

    @theaters = @theaters.select { |t| current_user.theaters.include?(t) } if current_user.is_theater_user?
    respond_to do |format|
      format.html # index.html.erb
      format.json do
        params.permit!
        render json: TheaterDatatable.new(params, view_context: view_context, current_user: current_user)
      end
    end
  end

  def show; end

  # GET /theaters/new
  # GET /theaters/new.xml
  def new
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render xml: @theater }
    end
  end

  def edit; end

  # POST /theaters
  # POST /theaters.xml
  def create
    respond_to do |format|
      if @theater.save
        flash[:notice] = 'Theater was successfully created.'
        format.html { redirect_to(admin_theaters_path) }
        format.xml  { render xml: @theater, status: :created, location: @theater }
      else
        format.html { render action: 'new' }
        format.xml  { render xml: @theater.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /theaters/1
  # PUT /theaters/1.xml
  def update
    respond_to do |format|
      if @theater.update(theater_params)
        flash[:notice] = 'Theater was successfully updated.'
        format.html { redirect_to return_to_path(admin_theater_path(@theater)) }
        format.xml  { head :ok }
      else
        format.html { render action: 'edit' }
        format.xml  { render xml: @theater.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /theaters/1
  # DELETE /theaters/1.xml
  def destroy
    unless @theater.destroy
      flash[:error] = @theater.errors.full_messages.to_sentence
      return redirect_to(admin_theater_path(@theater))
    end

    respond_to do |format|
      format.html { redirect_to(admin_theaters_url) }
      format.xml  { head :ok }
    end
  end

  def remove_empty_logo
    sub = params[:theater]
    return unless sub

    params[:theater].delete(:logo) if params[:theater][:logo].blank?
  end

  private

  def theater_params
    params.require(:theater).permit(:name, :url, :theater_class, :logo, :status, :default_service_items,
                                    :default_first_exchange_items, :default_addl_exchange_items, :accepts_donations, :myemma_attendee_group, :tag_names,
                                    :donation_appeal, :secondary_donation_appeal, :sales_recorded_externally)
  end
end
