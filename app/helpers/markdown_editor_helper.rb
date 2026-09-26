# Markup for the markdown editor (admin/markdown_editor.js): the rendered
# preview under a header whose "Preview (click to edit)" button toggles the
# formatting toolbar and the field's own textarea in a panel below it. An email
# field's header can also carry "Send sample email" (SampleEmails) on its right. MarkdownInput wraps simple_form
# textareas in it; hand-built forms call markdown_editor directly.
module MarkdownEditorHelper
  MARKDOWN_TOOLBAR_BUTTONS = [
    { action: 'bold', icon: 'bold', title: 'Bold (Ctrl/⌘-B)' },
    { action: 'italic', icon: 'italic', title: 'Italic (Ctrl/⌘-I)' },
    { action: 'heading', icon: 'header', title: 'Heading' },
    { action: 'link', icon: 'link', title: 'Link (Ctrl/⌘-K)' },
    { action: 'bullets', icon: 'list-ul', title: 'Bulleted list' },
    { action: 'numbers', icon: 'list-ol', title: 'Numbered list' }
  ].freeze

  # Preview flavors: where the text is finally shown, and which renderer shows
  # it there. Emails use two renderers today -- OrderMailer's own
  # (@markdown_renderer: tables on, no safe_links) for confirmation, follow-up
  # and broadcast copy, and the site's (display_markdown) inside mail partials
  # such as special features and ticket annotations -- so the preview names
  # the one each field really goes through.
  MARKDOWN_PREVIEW_FLAVORS = {
    'web' => { label: 'Preview', renderer: :site },
    'email' => { label: 'Email preview', renderer: :mailer },
    'email_site' => { label: 'Email preview', renderer: :site }
  }.freeze

  # textarea: the field's rendered textarea (holds the raw stored text).
  # value:    that text, for the initial server-rendered preview.
  # open:     start with the editor showing (a blank compose box, a field with errors).
  #           The server always renders the editor open, so the field can still be
  #           edited without JavaScript; the script collapses it unless open.
  # flavor:   a MARKDOWN_PREVIEW_FLAVORS key.
  # sample:   { kind:, **context ids } -- offer "Send sample email" (a
  #           SampleEmails kind), shown only to staff allowed to send it.
  def markdown_editor(textarea, value:, editor_id:, open: false, flavor: 'web', sample: nil)
    content_tag(:div, class: 'markdown-editor is-editing',
                      data: { markdown_editor: true, markdown_flavor: flavor, markdown_start_open: open }) do
      markdown_editor_preview(value, editor_id, flavor, sample) +
        content_tag(:div, markdown_editor_toolbar + textarea, id: editor_id, class: 'markdown-editor__edit')
    end
  end

  def render_markdown_preview(text, flavor = 'web')
    return content_tag(:p, 'Nothing here yet.', class: 'markdown-editor__empty') if text.blank?

    if MARKDOWN_PREVIEW_FLAVORS.dig(flavor, :renderer) == :mailer
      raw(OrderMailer.new.markdown_renderer.render(text)) # rubocop:disable Rails/OutputSafety
    else
      display_markdown(text)
    end
  end

  private

  # Clicking the preview body also opens the editor, as a mouse convenience;
  # the header's toggle is the real (keyboard-reachable) control.
  def markdown_editor_preview(value, editor_id, flavor, sample)
    content_tag(:div, class: 'markdown-editor__preview-wrapper') do
      content_tag(:div, markdown_editor_toggle(editor_id, flavor) + markdown_sample_button(sample),
                  class: 'markdown-editor__header') +
        content_tag(:div, render_markdown_preview(value, flavor),
                    class: 'markdown-editor__preview', 'aria-live': 'polite')
    end
  end

  def markdown_editor_toggle(editor_id, flavor)
    content_tag(:button, type: 'button', class: 'markdown-editor__toggle',
                         'aria-expanded': 'true', 'aria-controls': editor_id) do
      content_tag(:span, MARKDOWN_PREVIEW_FLAVORS.fetch(flavor)[:label]) +
        content_tag(:span, ' (click to edit)', class: 'markdown-editor__edit-hint')
    end
  end

  def markdown_sample_button(sample)
    return ''.html_safe if sample.blank?

    kind = sample.fetch(:kind)
    return ''.html_safe unless SampleEmails.visible?(kind, current_ability, sample)

    email_name = SampleEmails.for(kind).email_name
    content_tag(:button, 'Send sample email',
                type: 'button', class: 'markdown-editor__sample',
                title: "Send a sample #{email_name}, with this form's unsaved changes, to #{current_user.email}",
                data: { markdown_sample: true, url: admin_sample_emails_path(sample),
                        email: current_user.email, email_name: email_name })
  end

  def markdown_editor_toolbar
    content_tag(:div, class: 'markdown-editor__toolbar', role: 'toolbar', 'aria-label': 'Formatting') do
      safe_join(MARKDOWN_TOOLBAR_BUTTONS.map { |button| markdown_editor_button(button) }) +
        content_tag(:button, 'Done', type: 'button', class: 'markdown-editor__done',
                                     data: { markdown_done: true })
    end
  end

  def markdown_editor_button(button)
    content_tag(:button, fa_icon(button[:icon]),
                type: 'button', class: 'markdown-editor__button',
                title: button[:title], 'aria-label': button[:title],
                data: { markdown_action: button[:action] })
  end
end
