require 'rails_helper'
require Rails.root.join('spec/support/shared_examples/taggable')

RSpec.describe FlexPassOfferTag, type: :model do
  it_behaves_like 'a taggable model' do
    let(:taggable) { FactoryBot.create(:flex_pass_offer) }
    let(:other_taggable) { FactoryBot.create(:flex_pass_offer, name: 'Other Pass') }
    let(:tag_class) { described_class }
  end
end
