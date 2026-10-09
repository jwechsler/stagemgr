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

  describe '#donation_appeal_for' do
    it 'uses the standard wording with the theater name when the appeal is blank' do
      theater = FactoryBot.build(:theater, name: 'Appeal House', donation_appeal: '')

      expect(theater.donation_appeal_for)
        .to eq('Yes! I love Appeal House. Please add a tax-deductible contribution to this order.')
    end

    it 'expands {{theater}} in a stored appeal' do
      theater = FactoryBot.build(:theater, name: 'Appeal House', donation_appeal: 'Support **{{theater}}** today.')

      expect(theater.donation_appeal_for).to eq('Support **Appeal House** today.')
    end
  end

  describe '#secondary_donation_appeal_for' do
    let(:company) { FactoryBot.build(:theater, name: ' Visiting Troupe ', theater_class: Theater::VISITING) }

    it 'expands {{theater}} and {{company}} in the secondary appeal' do
      theater = FactoryBot.build(:theater, name: 'Host House', theater_class: Theater::DEFAULT,
                                           secondary_donation_appeal: '{{theater}} supports {{company}}.')

      expect(theater.secondary_donation_appeal_for(company: company)).to eq('Host House supports Visiting Troupe.')
    end

    it 'falls back to the default appeal when the secondary appeal is blank' do
      theater = FactoryBot.build(:theater, name: 'Host House', theater_class: Theater::DEFAULT,
                                           donation_appeal: 'Give to {{theater}}.', secondary_donation_appeal: ' ')

      expect(theater.secondary_donation_appeal_for(company: company)).to eq('Give to Host House.')
    end

    it 'falls back to the standard wording when both appeals are blank' do
      theater = FactoryBot.build(:theater, name: 'Host House', theater_class: Theater::DEFAULT)

      expect(theater.secondary_donation_appeal_for(company: company))
        .to eq('Yes! I love Host House. Please add a tax-deductible contribution to this order.')
    end

    it 'leaves an empty string for {{company}} when there is no company' do
      theater = FactoryBot.build(:theater, name: 'Host House', secondary_donation_appeal: 'Helping {{company}}.')

      expect(theater.secondary_donation_appeal_for(company: nil)).to eq('Helping .')
    end
  end
end
