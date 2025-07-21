module ReportProcessor
  extend ActiveSupport::Concern

  # Common error types that reports encounter
  class ReportError < StandardError; end
  class DateParsingError < ReportError; end
  class DatabaseTimeoutError < ReportError; end
  class JobQueueError < ReportError; end
  class ParameterError < ReportError; end

  private

  # Main method to process any report with comprehensive error handling
  def process_report(options = {}, &block)
    log_report_access(options)
    
    begin
      validate_report_options!(options)
      
      if should_download?(options)
        queue_background_report(options)
      else
        generate_inline_report(options, &block)
      end
    rescue DateParsingError => e
      handle_date_error(e.message)
    rescue DatabaseTimeoutError => e
      handle_database_timeout_error
    rescue JobQueueError => e
      handle_job_queue_error(e.message)
    rescue ParameterError => e
      handle_parameter_error(e.message)
    rescue StandardError => e
      handle_generic_error(e)
    end
  end

  # Parse and validate date parameters with proper error handling
  def parse_date_params(date_params)
    parsed_dates = {}
    
    date_params.each do |key, value|
      begin
        parsed_dates[key] = value.to_date
      rescue Date::Error, ArgumentError
        raise DateParsingError, "Invalid #{key.to_s.humanize.downcase} format. Please use MM/DD/YYYY format."
      end
    end

    # Swap dates if start date is after end date
    if parsed_dates[:starting_date] && parsed_dates[:ending_date] && 
       parsed_dates[:starting_date] > parsed_dates[:ending_date]
      parsed_dates[:starting_date], parsed_dates[:ending_date] = 
        parsed_dates[:ending_date], parsed_dates[:starting_date]
    end

    # Validate date range size to prevent resource exhaustion
    validate_date_range_size(parsed_dates)

    parsed_dates
  end

  # Determine if this should be a download (background) or display (inline)
  def should_download?(options)
    params[:download].present? || params['download_csv'].present? || options[:force_background]
  end

  # Queue a background job with error handling
  def queue_background_report(options)
    begin
      Resque.enqueue(options[:job_class], *options[:job_params], current_user.id)
      flash[:notice] = options[:success_message] || 
        "Your export is queued for generation. You'll receive notification when the process is complete."
      redirect_to admin_reports_path
    rescue Redis::CannotConnectError, Resque::NoQueueError => e
      raise JobQueueError, "Report queueing system is temporarily unavailable. Please try again later."
    rescue StandardError => e
      raise JobQueueError, "Failed to queue report: #{e.message}"
    end
  end

  # Generate report inline with timeout protection
  def generate_inline_report(options, &block)
    begin
      timeout_seconds = options[:timeout] || $SERVER_CONFIG['report_timeout_seconds'] || 30
      Timeout::timeout(timeout_seconds.seconds) do
        if block_given?
          yield
        else
          report = options[:report_class].new(*options[:report_params])
          @headers, @report_data = report.create
        end
        
        if should_download?(options) && options[:csv_filename]
          send_report_as_csv(options[:csv_filename], @headers, @report_data)
        else
          respond_to { |format| format.html }
        end
      end
    rescue Timeout::Error
      raise DatabaseTimeoutError
    rescue ActiveRecord::StatementTimeout, Mysql2::Error::TimeoutError
      raise DatabaseTimeoutError
    end
  end

  # Validation for required options
  def validate_report_options!(options)
    if should_download?(options)
      required_keys = [:job_class, :job_params]
    else
      required_keys = options[:report_class] ? [:report_class, :report_params] : []
    end
    
    missing_keys = required_keys.select { |key| options[key].nil? }
    unless missing_keys.empty?
      raise ParameterError, "Missing required options: #{missing_keys.join(', ')}"
    end
  end

  # Validate date range size to prevent resource exhaustion attacks
  def validate_date_range_size(parsed_dates)
    return unless parsed_dates[:starting_date] && parsed_dates[:ending_date]
    
    start_date = parsed_dates[:starting_date]
    end_date = parsed_dates[:ending_date]
    days_span = (end_date - start_date).to_i
    
    # Maximum allowed date range (configurable, default to 2 years)
    max_days = $SERVER_CONFIG['max_report_date_range_days'] || 730
    
    if days_span > max_days
      raise ParameterError, "Date range too large. Maximum allowed range is #{max_days} days (#{max_days/365.0} years). Please use a smaller date range or the download option for large reports."
    end
    
    # Warn for very large ranges that should probably use background processing
    large_range_threshold = max_days / 4  # 6 months default
    if days_span > large_range_threshold && !should_download?({})
      Rails.logger.warn "Large date range requested for inline report: #{days_span} days (#{start_date} to #{end_date})"
    end
  end

  # Log report access for audit trails
  def log_report_access(options)
    report_name = options[:report_class]&.name || action_name
    report_type = should_download?(options) ? 'background' : 'inline'
    
    # Extract date parameters if present
    date_info = if params[:starting_date] && params[:ending_date]
      " (#{params[:starting_date]} to #{params[:ending_date]})"
    elsif params.dig(:report, :week_ending)
      " (week ending #{params[:report][:week_ending]})"
    else
      ""
    end
    
    Rails.logger.info "REPORT_ACCESS: User #{current_user.id} (#{current_user.email}) accessed #{report_name} report (#{report_type})#{date_info} from IP #{request.remote_ip}"
    
    # Log additional context for security monitoring
    if request.remote_ip && !is_internal_ip?(request.remote_ip)
      Rails.logger.info "REPORT_ACCESS_EXTERNAL: External IP #{request.remote_ip} accessed #{report_name} report by user #{current_user.id}"
    end
  end

  # Check if IP is internal/trusted
  def is_internal_ip?(ip)
    internal_ranges = [
      IPAddr.new('127.0.0.0/8'),    # localhost
      IPAddr.new('10.0.0.0/8'),     # private class A
      IPAddr.new('172.16.0.0/12'),  # private class B
      IPAddr.new('192.168.0.0/16'), # private class C
    ]
    
    internal_ranges.any? { |range| range.include?(IPAddr.new(ip)) }
  rescue IPAddr::InvalidAddressError
    false
  end

  # Error handlers
  def handle_date_error(message)
    flash[:error] = message
    redirect_to admin_reports_path
  end

  def handle_database_timeout_error
    flash[:error] = "This report is taking too long to generate. Please try a smaller date range or use the download option for large reports."
    redirect_to admin_reports_path
  end

  def handle_job_queue_error(message)
    flash[:error] = "Report generation is temporarily unavailable: #{message}"
    redirect_to admin_reports_path
  end

  def handle_parameter_error(message)
    flash[:error] = "Invalid parameters: #{message}"
    redirect_to admin_reports_path
  end

  def handle_generic_error(error)
    Rails.logger.error "Report generation error: #{error.class} - #{error.message}"
    Rails.logger.error error.backtrace.join("\n")
    
    # Add report-specific context for debugging
    report_context = {
      report_name: action_name,
      user_id: current_user&.id,
      user_email: current_user&.email,
      request_ip: request.remote_ip,
      parameters: params.except(:authenticity_token).to_hash
    }
    
    # Notify via the existing ExceptionNotifier system
    if defined?(ExceptionNotifier) && Rails.env.production?
      ExceptionNotifier.notify_exception(error, 
        env: request.env, 
        data: { report_context: report_context }
      )
    end
    
    # Provide more specific error message based on error type
    error_message = case error
    when ActiveRecord::StatementTimeout, Mysql2::Error::TimeoutError
      "The report is taking too long to generate due to the amount of data. Please try a smaller date range or use the download option."
    when ActiveRecord::ConnectionNotEstablished, Mysql2::Error::ConnectionError
      "Database connection issue. Please try again in a few moments."
    when NoMethodError
      "Report configuration error occurred. Our development team has been notified and will investigate this issue."
    else
      "An unexpected error occurred while generating the report (#{error.class}). Our development team has been notified. Please try again or contact support if the problem persists."
    end
    
    flash[:error] = error_message
    redirect_to admin_reports_path
  end
end