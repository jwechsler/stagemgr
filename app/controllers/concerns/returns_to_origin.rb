# Admin edit screens are reached from many places: an index (possibly
# filtered), a show page, the global productions list. After a successful
# update, send the admin back to the page the edit was opened from.
#
# The edit action captures that page from the request's referer into the
# form's hidden return_to field (shared/_return_to_field); update reads it
# back. Only a path on this site is honoured, so neither the referer nor a
# tampered field can redirect off-site. With no usable origin, the caller's
# default (normally the record's show page) is used.
module ReturnsToOrigin
  extend ActiveSupport::Concern

  included do
    helper_method :return_to_value
  end

  private

  # Where a successful update should go: the carried return_to, else default_path.
  def return_to_path(default_path)
    safe_return_path(params[:return_to]) || default_path
  end

  # Value for the form's hidden return_to field: a return_to already carried
  # (a re-rendered form after a validation error), else the referring page.
  def return_to_value
    safe_return_path(params[:return_to]) || referer_return_path
  end

  # The referring page as a site-relative path with its query string, when it
  # is on this host and is not this edit page itself (a reload).
  def referer_return_path
    uri = URI.parse(request.referer.to_s)
    return if uri.path.blank? || (uri.host.present? && uri.host != request.host)
    return if uri.path == request.path

    safe_return_path([uri.path, uri.query].compact.join('?'))
  rescue URI::InvalidURIError
    nil
  end

  # A site-relative path: starts with a single "/", so it can never name
  # another host ("//evil.example.com") or a scheme.
  def safe_return_path(value)
    value = value.to_s
    return unless value.start_with?('/') && !value.start_with?('//') && value.exclude?('\\')

    value
  end
end
