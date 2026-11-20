require 'rails_helper'

# Webpacker was replaced by jsbundling-rails + esbuild: `yarn build` writes
# app/assets/builds/seat_map_editor.js and Sprockets serves it via
# `//= link_tree ../builds`.
RSpec.describe 'JavaScript bundling through Sprockets' do
  it 'resolves the esbuild seat map editor bundle in the Sprockets environment' do
    asset = Rails.application.assets['seat_map_editor.js']

    expect(asset).not_to be_nil
    expect(asset.filename).to eq(Rails.root.join('app/assets/builds/seat_map_editor.js').to_s)
  end

  it 'precompiles the seat map editor bundle' do
    expect(Rails.application.precompiled_assets).to include('seat_map_editor.js')
  end

  it 'leaves no Webpacker references in app, config, lib or bin' do
    builds = Rails.root.join('app/assets/builds')
    files = Rails.root.glob('{app,config,lib,bin}/**/*')
                 .select(&:file?)
                 .reject { |path| path.to_s.start_with?("#{builds}/") }
    offenders = files.select do |path|
      path.binread.match?(/javascript_pack_tag|stylesheet_pack_tag|webpacker/i)
    end

    expect(offenders.map { |path| path.relative_path_from(Rails.root).to_s }).to eq([])
  end
end
