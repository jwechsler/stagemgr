require 'rails_helper'

RSpec.describe MarkdownInput, type: :helper do
  let(:festival) { Festival.new(description: "<b>Hand-written</b> and **markdown**") }

  def render_input(**options)
    Nokogiri::HTML(helper.simple_form_for(festival, url: '/festivals') do |f|
      f.input :description, as: :markdown, **options
    end)
  end

  it 'renders the raw stored text in an ordinary textarea, so saving never rewrites it' do
    textarea = render_input.at_css('.markdown-editor textarea[name="festival[description]"]')

    expect(textarea).to be_present
    # Rails emits a newline after <textarea> that browsers drop (HTML spec);
    # Nokogiri's HTML4 parser keeps it.
    expect(textarea.text.delete_prefix("\n")).to eq("<b>Hand-written</b> and **markdown**")
  end

  it 'shows the rendered value as a preview headed "Preview (click to edit)"' do
    html = render_input
    wrapper = html.at_css('.markdown-editor__preview-wrapper')

    expect(wrapper.at_css('button.markdown-editor__toggle').text).to eq('Preview (click to edit)')
    expect(wrapper.at_css('.markdown-editor__preview').inner_html)
      .to include('<b>Hand-written</b> and <strong>markdown</strong>')
  end

  it 'keeps the editor hidden until the preview is clicked' do
    html = render_input
    panel = html.at_css('.markdown-editor__edit')

    expect(panel['hidden']).to be_present
    expect(html.at_css('.markdown-editor__toggle')['aria-expanded']).to eq('false')
    expect(html.at_css('.markdown-editor__toggle')['aria-controls']).to eq(panel['id'])
  end

  it 'opens straight into the editor when the field has a validation error' do
    festival.errors.add(:description, 'is too long')
    html = render_input

    expect(html.at_css('.markdown-editor__edit')['hidden']).to be_nil
    expect(html.at_css('.markdown-editor.is-editing')).to be_present
  end

  it 'says so when there is nothing to preview' do
    festival.description = ''

    expect(render_input.at_css('.markdown-editor__preview').text).to eq('Nothing here yet.')
  end

  it 'offers a button for every toolbar action the editor script handles, plus Done' do
    buttons = render_input.css('.markdown-editor__toolbar button')

    expect(buttons.filter_map { |b| b['data-markdown-action'] }).to eq(%w[bold italic heading link bullets numbers])
    expect(buttons.last.text).to eq('Done')
    expect(buttons.pluck('type').uniq).to eq(['button'])
  end

  it 'labels an email-only field "Email preview" and previews it with the renderer that email uses' do
    html = render_input(preview: 'email')

    expect(html.at_css('.markdown-editor')['data-markdown-flavor']).to eq('email')
    expect(html.at_css('.markdown-editor__toggle').text).to eq('Email preview (click to edit)')
    expect(html.at_css('textarea')['preview']).to be_nil
  end

  describe 'sample:' do
    let(:user) { FactoryBot.create(:admin_user) }

    before do
      without_partial_double_verification do
        allow(helper).to receive_messages(current_user: user, current_ability: user.ability)
      end
    end

    it 'puts "Send sample email" in the header, after the toggle, for a user who may send it' do
      header = render_input(preview: 'email_site', sample: { kind: 'special_feature' }).at_css('.markdown-editor__header')

      expect(header.css('> button').map(&:text)).to eq(['Email preview (click to edit)', 'Send sample email'])
      expect(header.at_css('.markdown-editor__sample')['data-url']).to eq('/admin/sample_emails?kind=special_feature')
    end

    it 'keeps the option off the textarea' do
      expect(render_input(sample: { kind: 'special_feature' }).at_css('textarea')['sample']).to be_nil
    end

    it 'offers no sample without the option' do
      expect(render_input(preview: 'email').at_css('.markdown-editor__sample')).to be_nil
    end
  end

  it 'defaults to the web preview' do
    expect(render_input.at_css('.markdown-editor')['data-markdown-flavor']).to eq('web')
  end

  it 'keeps input_html options such as rows on the textarea' do
    expect(render_input(input_html: { rows: 7 }).at_css('textarea')['rows']).to eq('7')
  end
end
