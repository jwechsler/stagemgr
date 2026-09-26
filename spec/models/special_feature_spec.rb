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

RSpec.describe SpecialFeature, 'email text' do
  def feature(**attrs)
    described_class.create!({ short_name: "Feature #{SecureRandom.hex(3)}", status: described_class::ACTIVE,
                              description: 'Web description' }.merge(attrs))
  end

  it 'uses the Custom Email text in emails when it is set' do
    expect(feature(email_description: 'Email-only text').email_text).to eq('Email-only text')
  end

  it 'falls back to the description when Custom Email is blank' do
    expect(feature(email_description: '  ').email_text).to eq('Web description')
    expect(feature.email_text).to eq('Web description')
  end

  describe 'deleting a feature folds its texts into the performance custom fields' do
    let(:performance) { FactoryBot.create(:performance) }

    def delete_from(performance, feature)
      performance.special_features << feature
      feature.destroy!
      performance.reload
    end

    it 'appends the description to the custom display text and leaves email alone without email text' do
      performance.update!(special_feature_display_markdown: 'Existing custom')
      delete_from(performance, feature)

      expect(performance.special_feature_display_markdown).to eq("Existing custom\n\nWeb description")
      expect(performance.special_feature_email_markdown).to be_blank
    end

    it 'seeds the custom email with the display text it stood in for, plus the feature email text' do
      performance.update!(special_feature_display_markdown: 'Existing custom')
      delete_from(performance, feature(email_description: 'Email-only text'))

      expect(performance.special_feature_display_markdown).to eq("Existing custom\n\nWeb description")
      expect(performance.special_feature_email_markdown).to eq("Existing custom\n\nEmail-only text")
    end

    it 'adds the description to an existing custom email so emails keep showing it' do
      performance.update!(special_feature_email_markdown: 'Existing email')
      delete_from(performance, feature)

      expect(performance.special_feature_email_markdown).to eq("Existing email\n\nWeb description")
    end
  end
end
