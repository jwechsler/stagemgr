require 'rails_helper'

RSpec.describe Theater do
  describe 'destroy' do
    it 'is refused while the theater has productions' do
      theater = FactoryBot.create(:theater, name: 'Restricted House')
      FactoryBot.create(:production, theater: theater)

      expect(theater.destroy).to be false
      expect(Theater.exists?(theater.id)).to be true
    end

    it 'deletes a theater with no productions' do
      theater = FactoryBot.create(:theater, name: 'Empty House')

      expect(theater.destroy).to be_truthy
      expect(Theater.exists?(theater.id)).to be false
    end
  end
end
