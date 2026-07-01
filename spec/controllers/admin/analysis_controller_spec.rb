require 'rails_helper'

RSpec.describe Admin::AnalysisController, type: :controller do
  let(:theater)    { FactoryBot.create(:theater) }
  let(:production) { FactoryBot.create(:production, theater: theater) }

  let(:admin_user) do
    double('AdminUser',
           id: 1,
           email: 'admin@example.com',
           is_administrator?: true,
           theater_ids: [theater.id])
  end

  let(:theater_user) do
    double('TheaterUser',
           id: 2,
           email: 'theater@example.com',
           is_administrator?: false,
           theater_ids: [theater.id])
  end

  before do
    allow(controller).to receive(:authorize!).and_return(true)
    allow(controller).to receive(:current_ability).and_return(double('Ability'))
    accessible_scope = double('AccessibleProductions')
    allow(Production).to receive(:accessible_by).and_return(accessible_scope)
    allow(accessible_scope).to receive(:find).with(production.id.to_s).and_return(production)
    allow(controller).to receive(:can?).and_return(true)
  end

  describe 'POST #audience_export' do
    let(:base_params) do
      {
        target_production_id: production.id,
        comparison_theater_ids: [theater.id.to_s],
        segment_key: 'first_time_vs_comparison',
        window_label: '3 months'
      }
    end

    context 'as an admin user' do
      before { allow(controller).to receive(:current_user).and_return(admin_user) }

      it 'enqueues AudienceCohortExport with the right args and flashes a notice' do
        expect(Resque).to receive(:enqueue).with(
          AudienceCohortExport,
          production.id,
          [theater.id],
          'first_time_vs_comparison',
          '3 months',
          true, # can?(:view_email, Address) stubbed to true
          [theater.id],
          admin_user.id
        )

        post :audience_export, params: base_params
        expect(flash[:notice]).to match(/cohort export is queued/i)
        expect(response).to redirect_to(admin_analysis_index_path(target_production_id: production.id,
                                                                  analysis_type: 'audience', comparison_theater_ids: [theater.id]))
      end

      it 'allows facility-scope exports for admin users' do
        expect(Resque).to receive(:enqueue).with(AudienceCohortExport, anything, anything, 'three_plus_in_building',
                                                 anything, anything, anything, anything)
        post :audience_export, params: base_params.merge(segment_key: 'three_plus_in_building')
      end
    end

    context 'as a theater (non-admin) user' do
      before { allow(controller).to receive(:current_user).and_return(theater_user) }

      it 'allows comparison-scope exports' do
        expect(Resque).to receive(:enqueue).with(AudienceCohortExport, anything, anything, 'first_time_vs_comparison',
                                                 anything, anything, [theater.id], theater_user.id)
        post :audience_export, params: base_params
      end

      it 'blocks facility-scope exports with a flash error' do
        expect(Resque).not_to receive(:enqueue)
        post :audience_export, params: base_params.merge(segment_key: 'three_plus_in_building')
        expect(flash[:error]).to match(/administrators/i)
        expect(response).to redirect_to(admin_analysis_index_path(target_production_id: production.id,
                                                                  analysis_type: 'audience', comparison_theater_ids: [theater.id]))
      end

      %w[first_time_vs_building returning_vs_building three_plus_in_building].each do |key|
        it "blocks facility-scope segment #{key}" do
          expect(Resque).not_to receive(:enqueue)
          post :audience_export, params: base_params.merge(segment_key: key)
        end
      end
    end
  end
end
