require 'rails_helper'

RSpec.describe SpecialFeature do
  it 'scrubs pasted invisible characters from the description' do
    feature = described_class.create!(short_name: 'Blackout',
                                      status: described_class::ACTIVE,
                                      description: "﻿Dedicated to ﻿Black-identifying theatergoers")

    expect(feature.reload.description).to eq('Dedicated to Black-identifying theatergoers')
  end

  it 'stores legitimate typography unchanged' do
    typography = "Open captioned — “accessible” for all… café seating"
    feature = described_class.create!(short_name: 'Captioned',
                                      status: described_class::ACTIVE,
                                      description: typography)

    expect(feature.reload.description).to eq(typography)
  end
end
