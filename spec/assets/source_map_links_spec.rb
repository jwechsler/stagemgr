require 'rails_helper'

# Sprockets-rails rewrites a library's `sourceMappingURL` comment into a
# digested asset path but does not link that asset, so unless the map is
# precompiled the browser's request for it 404s.
RSpec.describe 'source map references in JavaScript bundles' do
  let(:digested_path) { /\A(?<logical>.+)-\h{64}(?<ext>\.map)\z/ }

  def source_map_paths(logical_path)
    asset = Rails.application.assets[logical_path]
    raise "Sprockets cannot find #{logical_path}" if asset.nil?

    prefix = "#{Rails.application.config.assets.prefix}/"
    asset.to_s.scan(/sourceMappingURL=(\S+)/).flatten.map { |url| url.delete_prefix(prefix) }
  end

  %w[application.js frontend.js].each do |logical_path|
    describe logical_path do
      let(:paths) { source_map_paths(logical_path) }

      it 'carries the Foundation source map reference' do
        expect(paths).to include(%r{\Afoundation-sites/dist/js/foundation\.js-\h{64}\.map\z})
      end

      it 'names only source maps that the pipeline finds and precompiles' do
        paths.each do |path|
          match = digested_path.match(path)
          expect(match).not_to be_nil, "#{path} is not a digested .map path"

          map_logical_path = "#{match[:logical]}#{match[:ext]}"
          expect(Rails.application.assets[map_logical_path]&.digest_path).to eq(path)
          expect(Rails.application.precompiled_assets).to include(map_logical_path)
        end
      end
    end
  end
end
