require 'rails_helper'

# The public order page outlines a PNG seat map with .seating-layout__map--outlined.
# Public layouts load the frontend stylesheet, so the rule must be in that bundle
# or the class does nothing.
RSpec.describe 'seat map styles in the frontend stylesheet' do
  let(:source) do
    asset = Rails.application.assets['frontend.css']
    raise 'Sprockets cannot find frontend.css' if asset.nil?

    asset.to_s
  end

  it 'gives the outlined seat map a 1px solid border' do
    rule = source.match(/\.seating-layout__map--outlined\s*\{(?<body>[^}]*)\}/)

    expect(rule).not_to be_nil, 'frontend.css has no .seating-layout__map--outlined rule'
    expect(rule[:body]).to match(/border\s*:\s*1px\s+solid\b/)
  end
end
