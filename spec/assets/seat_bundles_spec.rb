require 'rails_helper'

# The seat-map scripts are included on pages whose layout already loads the
# libraries they use (admin: the `application` bundle; public: the `frontend`
# bundle), so they carry only their own code. `frontend` carries exactly the
# libraries public order pages share, once each.
module SeatBundleMarkers
  JS_ROOT = Rails.root.join('app/assets/javascripts')

  # Stable text that appears once in each library's source.
  LIBRARY_MARKERS = {
    'jQuery' => 'jQuery JavaScript Library',
    'jquery_ujs' => 'jquery-ujs has already been loaded',
    'Foundation Reveal' => 'function Reveal() {',
    'reveal_confirm' => 'function revealConfirmBuild',
    'revealAlert' => 'function revealAlert'
  }.freeze

  ADMIN_ONLY_MARKERS = {
    'DataTables' => 'DataTables',
    'jQuery UI' => 'jQuery UI'
  }.freeze

  # Page code that belongs in the page's own scripts, not in frontend.
  PAGE_CODE_MARKERS = {
    'seat_assignment' => 'function initialize_seating_assignment',
    'utility' => 'function formatCurrency'
  }.freeze

  # seat_assignment's own code and the seat_map code it requires.
  SEAT_ASSIGNMENT_MARKERS = {
    'initialize_seating_assignment' => 'function initialize_seating_assignment',
    'seat_map' => 'function initialize_seatingmap'
  }.freeze

  SHARED_LIBRARIES = ['jQuery', 'jquery_ujs', 'Foundation Reveal', 'reveal_confirm'].freeze
  REQUIRE_APPLICATION = %r{^\s*//=\s*require\s+application(\.js)?\s*$}
end

RSpec.describe 'seat-map JavaScript bundles' do
  def bundle_source(logical_path)
    asset = Rails.application.assets[logical_path]
    raise "Sprockets cannot find #{logical_path}" if asset.nil?

    asset.to_s
  end

  %w[seat_map.js seat_assignment.js reseating.js].each do |logical_path|
    describe logical_path do
      let(:source) { bundle_source(logical_path) }

      SeatBundleMarkers::SHARED_LIBRARIES.each do |library|
        it "does not bundle #{library}" do
          expect(source).not_to include(SeatBundleMarkers::LIBRARY_MARKERS.fetch(library))
        end
      end

      SeatBundleMarkers::ADMIN_ONLY_MARKERS.each do |library, marker|
        it "does not bundle #{library}" do
          expect(source).not_to include(marker)
        end
      end
    end
  end

  describe 'seat_assignment.js' do
    let(:source) { bundle_source('seat_assignment.js') }

    SeatBundleMarkers::SEAT_ASSIGNMENT_MARKERS.each do |code, marker|
      it "contains the #{code} code exactly once" do
        expect(source.scan(marker).size).to eq(1)
      end
    end
  end

  describe 'frontend.js' do
    let(:source) { bundle_source('frontend.js') }

    SeatBundleMarkers::LIBRARY_MARKERS.each do |library, marker|
      it "bundles #{library} exactly once" do
        expect(source.scan(marker).size).to eq(1)
      end
    end

    SeatBundleMarkers::PAGE_CODE_MARKERS.each do |code, marker|
      it "does not bundle #{code}" do
        expect(source).not_to include(marker)
      end
    end

    SeatBundleMarkers::ADMIN_ONLY_MARKERS.each do |library, marker|
      it "does not bundle #{library}" do
        expect(source).not_to include(marker)
      end
    end
  end

  it 'has no public_seating.js asset' do
    expect(Rails.application.assets['public_seating.js']).to be_nil
  end

  it 'has no JavaScript file that requires the application bundle' do
    requirers = Dir[SeatBundleMarkers::JS_ROOT.join('**/*.{js,erb}')].select do |path|
      File.read(path).match?(SeatBundleMarkers::REQUIRE_APPLICATION)
    end
    expect(requirers.map { |path| Pathname(path).relative_path_from(Rails.root).to_s }).to eq([])
  end
end
