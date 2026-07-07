require 'rails_helper'
require Rails.root.join('spec/support/shared_examples/taggable')

RSpec.describe TheaterTag, type: :model do
  it_behaves_like 'a taggable model' do
    let(:taggable) { FactoryBot.create(:theater) }
    let(:other_taggable) { FactoryBot.create(:theater, name: 'Other House') }
    let(:tag_class) { described_class }
  end
end
