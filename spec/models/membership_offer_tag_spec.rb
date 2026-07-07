require 'rails_helper'
require Rails.root.join('spec/support/shared_examples/taggable')

RSpec.describe MembershipOfferTag, type: :model do
  it_behaves_like 'a taggable model' do
    let(:taggable) { FactoryBot.create(:membership_offer) }
    let(:other_taggable) { FactoryBot.create(:membership_offer, name: 'Other Offer') }
    let(:tag_class) { described_class }
  end
end
