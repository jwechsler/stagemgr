require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  # Follow-up emails link to a survey and a mailing-list signup. Both default to
  # the house-wide URLs in config/server.yml, and a production may override
  # either one for the run of that show.
  describe 'follow-up link overrides' do
    let(:generic_survey)  { Rails.configuration.x.server_config['survey_link'] }
    let(:generic_mailing) { Rails.configuration.x.server_config['mailing_list_link'] }

    describe '#survey_link' do
      it 'returns the house survey when no production is given' do
        expect(helper.survey_link).to eq(generic_survey)
      end

      it 'returns the house survey when the production has no override' do
        production = FactoryBot.build(:production, survey_link: nil)
        expect(helper.survey_link(production)).to eq(generic_survey)
      end

      it 'returns the house survey when the override is an empty string' do
        production = FactoryBot.build(:production, survey_link: '')
        expect(helper.survey_link(production)).to eq(generic_survey)
      end

      it 'returns the production override when one is set' do
        production = FactoryBot.build(:production, survey_link: 'https://survey.test/custom')
        expect(helper.survey_link(production)).to eq('https://survey.test/custom')
      end
    end

    describe '#mailing_list_link' do
      it 'returns the house mailing list when no production is given' do
        expect(helper.mailing_list_link).to eq(generic_mailing)
      end

      it 'returns the house mailing list when the production has no override' do
        production = FactoryBot.build(:production, mailing_list_link: nil)
        expect(helper.mailing_list_link(production)).to eq(generic_mailing)
      end

      it 'returns the production override when one is set' do
        production = FactoryBot.build(:production, mailing_list_link: 'https://mailing.test/custom')
        expect(helper.mailing_list_link(production)).to eq('https://mailing.test/custom')
      end
    end
  end

  # Several partials on one page name the house, and each lookup would otherwise
  # query for the Default theater row again.
  describe '#theater_info' do
    it 'returns the house facts' do
      expect(helper.theater_info).to be_a(TheaterInfo)
    end

    it 'builds one instance per render and reuses it' do
      expect(helper.theater_info).to equal(helper.theater_info)
    end
  end
end
