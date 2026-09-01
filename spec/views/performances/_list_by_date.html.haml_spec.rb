require 'rails_helper'

# The small-format calendar renders the footnote list the large-format month
# grid also uses. Identical "Custom Special Feature" copy must appear once.
RSpec.describe 'performances/_list_by_date.html.haml', type: :view do
  let(:production) { FactoryBot.create(:production) }

  def performance_with(time, markdown)
    perf = FactoryBot.create(:performance, production: production,
                                           performance_date: Date.current + 1.day,
                                           performance_time: Time.parse(time))
    perf.update!(special_feature_display_markdown: markdown)
    perf
  end

  def render_list(performances)
    footnotes = performances.map(&:custom_footnote_key).compact.uniq
    render partial: 'performances/list_by_date',
           locals: { performances: performances, footnotes: footnotes }
    rendered
  end

  it 'prints shared custom copy as a single footnote' do
    performances = [performance_with('19:00', 'Post-show discussion'),
                    performance_with('20:00', 'Post-show discussion')]

    output = render_list(performances)

    expect(output.scan('Post-show discussion').length).to eq(1)
    expect(output).to include('[1] Post-show discussion')
    expect(output).not_to include('[2]')
  end

  it 'prints distinct custom copy as separate numbered footnotes' do
    performances = [performance_with('19:00', 'Open captioned'),
                    performance_with('20:00', 'ASL interpreted')]

    output = render_list(performances)

    expect(output).to include('[1] Open captioned')
    expect(output).to include('[2] ASL interpreted')
  end

  it 'marks both performances sharing the copy with the same superscript' do
    performances = [performance_with('19:00', 'Post-show discussion'),
                    performance_with('20:00', 'Post-show discussion')]

    output = render_list(performances)

    expect(output.scan('<sup>[1]&nbsp;</sup>').length).to eq(2)
  end

  it 'renders a SpecialFeature footnote by short_name' do
    feature = SpecialFeature.create!(short_name: 'OC', description: 'Open captioned',
                                     status: SpecialFeature::ACTIVE)
    perf = performance_with('19:00', nil)
    perf.special_features << feature

    render partial: 'performances/list_by_date',
           locals: { performances: [perf], footnotes: ['OC'] }

    expect(rendered).to include('[1] Open captioned')
  end
end
