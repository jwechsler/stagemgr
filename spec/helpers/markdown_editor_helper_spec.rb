require 'rails_helper'

RSpec.describe MarkdownEditorHelper, type: :helper do
  def render_editor(**options)
    textarea = helper.text_area_tag('body', '', id: 'broadcast-body')
    Nokogiri::HTML(helper.markdown_editor(textarea, value: '', editor_id: 'body-editor', **options))
  end

  it 'starts open, with the textarea showing, when asked (a blank compose box)' do
    html = render_editor(open: true)

    expect(html.at_css('#body-editor')['hidden']).to be_nil
    expect(html.at_css('#body-editor textarea#broadcast-body')).to be_present
    expect(html.at_css('.markdown-editor__toggle')['aria-expanded']).to eq('true')
  end

  it 'labels an email preview and tells the script which renderer to use' do
    html = render_editor(flavor: 'email')

    expect(html.at_css('.markdown-editor')['data-markdown-flavor']).to eq('email')
    expect(html.at_css('.markdown-editor__toggle').text).to eq('Email preview (click to edit)')
  end

  describe 'the header' do
    let(:user) { FactoryBot.create(:admin_user) }

    before do
      without_partial_double_verification do
        allow(helper).to receive_messages(current_user: user, current_ability: user.ability)
      end
    end

    it 'toggles the editor with a real button that says whether it is open and what it controls' do
      toggle = render_editor.at_css('.markdown-editor__header > button.markdown-editor__toggle')

      expect(toggle['type']).to eq('button')
      expect(toggle['aria-expanded']).to eq('false')
      expect(toggle['aria-controls']).to eq('body-editor')
    end

    it 'offers "Send sample email" after the toggle when given a sample the user may send' do
      header = render_editor(flavor: 'email', sample: { kind: 'special_feature' }).at_css('.markdown-editor__header')
      buttons = header.css('> button')
      sample = buttons.last

      expect(buttons.pluck('class')).to eq(%w[markdown-editor__toggle markdown-editor__sample])
      expect(sample.text).to eq('Send sample email')
      expect(sample['type']).to eq('button')
      expect(sample['title']).to include('confirmation email', user.email)
      expect(sample['data-markdown-sample']).to be_present
      expect(sample['data-url']).to eq('/admin/sample_emails?kind=special_feature')
    end

    it 'leaves the sample button out when its production does not exist' do
      html = render_editor(sample: { kind: 'production_confirmation', production_id: 0 })

      expect(html.at_css('.markdown-editor__sample')).to be_nil
    end

    it 'puts the context ids in the sample URL' do
      production = FactoryBot.create(:production)
      url = render_editor(sample: { kind: 'production_confirmation', production_id: production.id })
            .at_css('.markdown-editor__sample')['data-url']
      expect(url).to eq("/admin/sample_emails?kind=production_confirmation&production_id=#{production.id}")
    end

    it 'leaves the sample button out without a sample' do
      expect(render_editor(flavor: 'email').at_css('.markdown-editor__sample')).to be_nil
    end

    it 'leaves the sample button out for a user who may not send it' do
      theater_user = FactoryBot.create(:user)
      without_partial_double_verification do
        allow(helper).to receive_messages(current_user: theater_user, current_ability: theater_user.ability)
      end

      expect(render_editor(sample: { kind: 'special_feature' }).at_css('.markdown-editor__sample')).to be_nil
    end

    it 'leaves the sample button out for an unknown kind' do
      expect(render_editor(sample: { kind: 'bogus' }).at_css('.markdown-editor__sample')).to be_nil
    end
  end

  describe '#render_markdown_preview' do
    it 'renders email text with the mailer renderer' do
      expect(helper.render_markdown_preview("| a |\n|---|\n| b |", 'email')).to include('<table>')
    end

    it 'renders web text with the site renderer' do
      expect(helper.render_markdown_preview('**hi**')).to include('<strong>hi</strong>')
    end
  end
end
