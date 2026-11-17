require 'rails_helper'

# The seat-map scripts are included on pages whose layout already loads the
# libraries they use (admin: the `application` bundle), so they carry only
# their own code. The public reserved-seating order page has no such layout
# bundle and includes `public_seating`, which carries exactly the libraries
# seat_assignment needs, once each.
module SeatBundleMarkers
  JS_ROOT = Rails.root.join('app/assets/javascripts')

  # Stable text that appears once in each library's source.
  LIBRARY_MARKERS = {
    'jQuery' => 'jQuery JavaScript Library',
    'jquery_ujs' => 'jquery-ujs has already been loaded',
    'Foundation Reveal' => 'function Reveal() {',
    'reveal_confirm' => 'function revealConfirmBuild',
    'revealAlert' => 'function revealAlert',
    'utility' => 'function formatCurrency',
    'seat_assignment' => 'function initialize_seating_assignment'
  }.freeze

  ADMIN_ONLY_MARKERS = {
    'DataTables' => 'DataTables',
    'jQuery UI' => 'jQuery UI'
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

  describe 'public_seating.js' do
    let(:source) { bundle_source('public_seating.js') }

    SeatBundleMarkers::LIBRARY_MARKERS.each do |library, marker|
      it "bundles #{library} exactly once" do
        expect(source.scan(marker).size).to eq(1)
      end
    end

    SeatBundleMarkers::ADMIN_ONLY_MARKERS.each do |library, marker|
      it "does not bundle #{library}" do
        expect(source).not_to include(marker)
      end
    end
  end

  it 'has no JavaScript file that requires the application bundle' do
    requirers = Dir[SeatBundleMarkers::JS_ROOT.join('**/*.{js,coffee,erb}')].select do |path|
      File.read(path).match?(SeatBundleMarkers::REQUIRE_APPLICATION)
    end
    expect(requirers.map { |path| Pathname(path).relative_path_from(Rails.root).to_s }).to eq([])
  end
end
