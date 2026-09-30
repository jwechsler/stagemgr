require 'rails_helper'

# CSV is stdlib but not loaded at boot, so a file that uses it without its own
# `require 'csv'` only works when some other CSV-using class happened to load
# first. Admin::ReportsHelper.save_report_as_csv raised NameError in a fresh
# process that way. Checked statically because in-suite something has always
# loaded CSV already.
RSpec.describe 'CSV usage' do
  let(:csv_use) { /^[^#\n]*\bCSV(\.|::)/ }
  let(:csv_require) { /^\s*require ['"]csv['"]/ }

  it 'requires csv in every app and lib file that uses it' do
    offenders = Rails.root.glob('{app,lib,sites}/**/*.rb').select do |path|
      source = path.read
      source.match?(csv_use) && !source.match?(csv_require)
    end

    expect(offenders.map { |p| p.relative_path_from(Rails.root).to_s }).to be_empty
  end
end
