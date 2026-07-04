class CurrentUser::TheatersController < CurrentUser::ApplicationController
  # GET /theaters
  # GET /theaters.xml
  def index
    @theaters = Theater.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render xml: @theaters }
    end
  end

  # GET /theaters/new
  # GET /theaters/new.xml
  def new
    @theater = Theater.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render xml: @theater }
    end
  end

  # GET /theaters/1/edit
  def edit
    @theater = Theater.find(params[:id])
  end

  # POST /theaters
  # POST /theaters.xml
  def create
    @theater = Theater.new(params[:theater])

    respond_to do |format|
      if @theater.save
        flash[:notice] = 'Theater was successfully created.'
        format.html { redirect_to(current_user_theaters_path) }
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
    @theater = Theater.find(params[:id])

    respond_to do |format|
      if @theater.update(params[:theater])
        flash[:notice] = 'Theater was successfully updated.'
        format.html { redirect_to(current_user_theaters_path) }
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
    @theater = Theater.find(params[:id])
    @theater.destroy

    respond_to do |format|
      format.html { redirect_to(current_user_theaters_url) }
      format.xml  { head :ok }
    end
  end
end
