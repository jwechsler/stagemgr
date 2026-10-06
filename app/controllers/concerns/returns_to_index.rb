# Admin edit screens are reached from an index (whose Edit button passes
# return_to=index) or a show page. After a successful update, send the admin
# back where they came from. Only the known value is honoured, so the param
# can't redirect off-site.
module ReturnsToIndex
  extend ActiveSupport::Concern

  RETURN_TO_INDEX = 'index'.freeze

  private

  def return_to_index_or(record_path, index_path)
    params[:return_to] == RETURN_TO_INDEX ? index_path : record_path
  end
end
