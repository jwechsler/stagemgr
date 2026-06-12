# Single-segment TRG CSV export for one cohort produced by Audience Analysis.
#
# Each instance produces ONE FileStore CSV containing the addresses that fit a
# given (production, comparison_theaters, segment_key, window_label) tuple.
# The :Segment column is derived from those inputs and capped at 50 characters
# (TRG Arts list-name limit).
class AudienceCohortReport < MailingList
  SEGMENT_NAME_LIMIT = 50

  # Terse metric labels designed to keep the assembled segment name short.
  METRIC_LABELS = {
    "cohort" => "Attendees",
    "returning_any" => "Returning (any prior)",
    "first_time_vs_comparison" => "First Time (group)",
    "returning_vs_comparison" => "Returning (group)",
    "dedicated_customers" => "Dedicated",
    "two_plus_in_comparison" => "2+ visits (group)",
    "first_time_vs_building" => "First Time (facility)",
    "returning_vs_building" => "Returning (facility)",
    "three_plus_in_building" => "3+ visits (facility)"
  }.freeze

  WINDOW_PHRASES = {
    "3 months" => "Last 3mo",
    "6 months" => "Last 6mo",
    "1 year" => "Last 1yr",
    "3 years" => "Last 3yr",
    "5 years" => "Last 5yr",
    "Ever" => "Ever"
  }.freeze

  attr_reader :target_production, :comparison_theater_ids, :segment_key,
              :window_label, :allow_email_export, :segment_name

  def initialize(target_production_id, comparison_theater_ids, segment_key,
                 window_label, allow_email_export, theater_ids,
                 reporting_user_id)
    super(reporting_user_id, theater_ids: theater_ids)
    @target_production      = Production.find(target_production_id)
    @comparison_theater_ids = Array(comparison_theater_ids).map(&:to_i)
    @segment_key            = segment_key.to_s
    @window_label           = window_label.presence
    @allow_email_export     = allow_email_export ? true : false
    @segment_name           = build_segment_name
    # Append the opt-in indicator to the TRG header set. :Email may still be
    # blanked per-row based on view_email permission + Emma group membership.
    self.headers            = TRG_IMPORT_HEADERS + [:OptedInForEmail]
    # TRG :Segment column carries the three-letter list-type code; the
    # descriptive cohort name goes into :Title (the "segment title").
    @data = { TRG_SEGMENT_CODE => [] }
  end

  # TRG Arts list-type code used in the :Segment column for every cohort
  # export row. "LST" matches the convention CustomerMailingList already uses
  # for general patron lists.
  TRG_SEGMENT_CODE = 'LST'.freeze

  def create
    analysis = AudienceAnalysis.new(@target_production, @comparison_theater_ids)
    address_ids = analysis.cohort_for(@segment_key, @window_label)

    opt_in_productions =
      [@target_production] +
      Production.where(theater_id: @comparison_theater_ids).to_a
    email_allowlist =
      Admin::ReportsHelper.attendees_on_email_list_for_productions(opt_in_productions)

    Address.where(id: address_ids.to_a).find_each(batch_size: 1000) do |addr|
      email_downcased = addr.email.to_s.downcase
      is_opted_in    = email_downcased.present? && email_allowlist.key?(email_downcased)
      include_email  = @allow_email_export || is_opted_in

      hash = self.mailing_hash_from_buyer(addr, include_email)
      hash[:Title]           = @segment_name
      hash[:Season]          = @target_production.season.to_i
      hash[:OptedInForEmail] = is_opted_in ? "Y" : "N"
      @data[TRG_SEGMENT_CODE] << hash
    end

    file_name = report_filename(File.join(Dir.tmpdir, default_basename))
    save_report_to_filestore(file_name, "Audience cohort: #{@segment_name}")
  end

  private

  def default_basename
    parts = [
      "audience",
      @target_production.production_code.to_s.parameterize,
      segment_slug,
      (@window_label || "aggregate").parameterize
    ]
    "#{parts.join('_')}.csv"
  end

  # Filename-safe representation of the segment. For previous_production keys,
  # uses the prior production's production_code instead of its database id so
  # the file name stays human-readable.
  def segment_slug
    if @segment_key.start_with?("previous_production:")
      prev = previous_production
      code = prev&.production_code.presence || "prev"
      "returning_from_#{code.parameterize}"
    else
      @segment_key.parameterize
    end
  end

  # Builds the TRG Segment label as
  #   "<PRODUCTION_CODE> - <Metric label> - <Window phrase>"
  # and truncates to fit within SEGMENT_NAME_LIMIT chars, dropping pieces
  # from the right when the assembled string is too long.
  def build_segment_name
    pieces = [
      @target_production.production_code.to_s.upcase,
      metric_label_for(@segment_key),
      window_phrase_for(@window_label)
    ].reject { |p| p.nil? || p.empty? }

    while pieces.size > 1 && pieces.join(" - ").length > SEGMENT_NAME_LIMIT
      pieces.pop
    end
    pieces.join(" - ")[0, SEGMENT_NAME_LIMIT]
  end

  def metric_label_for(key)
    return METRIC_LABELS[key] if METRIC_LABELS.key?(key)

    if key.start_with?("previous_production:")
      prev_code = previous_production&.production_code.presence || "prev"
      return "Returning from #{prev_code.upcase}"
    end
    key
  end

  # Memoized lookup of the prior Production referenced by a
  # "previous_production:<id>" segment key. Returns nil for other keys.
  def previous_production
    return @previous_production if defined?(@previous_production)

    @previous_production =
      if @segment_key.start_with?("previous_production:")
        Production.find_by(id: @segment_key.split(":", 2).last.to_i)
      end
  end

  def window_phrase_for(label)
    return nil if label.nil?

    WINDOW_PHRASES[label] || label
  end
end
