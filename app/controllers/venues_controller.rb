class VenuesController < ApplicationController
  layout Rails.configuration.x.server_config['ext_site_wrapper']
  before_action :set_background

  # The public now-playing widgets are fetched hundreds of times an hour and
  # each build walks every venue's productions; serve the rendered widget
  # body from cache (the layout renders outside it).
  WIDGET_CACHE_TTL = 5.minutes

  def now_playing_fb
    body = cached_widget(:now_playing_fb) do
      set_now_playing_productions
      @now_playing_productions += @offtime_productions
      @home_shows = @now_playing_productions.select { |prod| prod.theater.producing? }
      @now_playing_productions -= @home_shows
      @max_pieces = 3
    end
    render html: body, layout: 'facebook'
  end

  def now_playing
    respond_to do |format|
      format.html do
        body = cached_widget(:now_playing) do
          set_now_playing_productions
          @max_pieces = 4
        end
        render html: body, layout: false
      end
    end
  end

  def now_playing_vertical
    body = cached_widget(:now_playing_vertical) { set_now_playing_productions }
    render html: body, layout: true
  end

  def set_background
    @background = params['background']
    @background = 'light' if @background.nil?
    @background = 'light' unless %w[light dark].include?(@background)
  end

  def current_shows
    @now_playing_productions = now_playing_by_venue(Production::PRIMETIME) + now_playing_by_venue(Production::OFF_TIME)
  end

  def offtime_now_playing; end

  def primetime_up_next; end

  def offtime_up_next; end

  def now_playing_by_venue(production_type)
    now_playing_productions = []
    Venue.all.sort.each do |venue|
      prods = venue.now_playing_or_next_up(production_type)
      now_playing_productions += prods
    end
    now_playing_productions
  end

  protected

  # Rendered widget body (no layout), built by running the block to gather
  # the productions and rendering +template+. Keyed on the date because the
  # widgets' contents depend on it.
  def cached_widget(template)
    Rails.cache.fetch(widget_cache_key, expires_in: WIDGET_CACHE_TTL) do
      yield
      render_to_string(template, layout: false)
    end.html_safe # rubocop:disable Rails/OutputSafety -- our own rendered template output
  end

  def widget_cache_key
    ['venues/widget', action_name, @background, Date.current.iso8601]
  end

  def set_now_playing_productions
    festival_members = []
    @now_playing_productions = []
    Venue.all.sort.each do |venue|
      # Grouped festival members never occupy the venue's slot (current show,
      # else next up) — they render in the festival block instead, and the
      # venue contributes no thumb of its own while the festival holds it.
      prods = if venue.external?
                venue.now_playing(Production::PRIMETIME, Date.current.end_of_week + 1.week)
              else
                venue.now_playing_or_next_up(Production::PRIMETIME)
              end
      members, others = prods.partition(&:festival_grouped?)
      festival_members += members
      @now_playing_productions += others
    end
    @offtime_productions = []
    Venue.all.each do |venue|
      prods = venue.now_playing(Production::OFF_TIME, Date.current.end_of_week + 3.days)
      members, others = prods.partition(&:festival_grouped?)
      festival_members += members
      @offtime_productions += others
    end
    build_festival_blocks(festival_members)
  end

  # Grouped festival members (Production#festival_grouped?) never render as
  # loose venue thumbs; group them into blocks that render after the per-venue
  # listings. A festival's lone remaining show is not grouped and rides the
  # regular venue flow.
  def build_festival_blocks(festival_members)
    @festival_blocks = festival_members.map(&:festival).uniq.map do |festival|
      { festival: festival, featured: festival.featured_productions(3), all: festival.public_productions }
    end
  end
end
