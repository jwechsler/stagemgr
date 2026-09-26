# A markdown-enabled field shown as its rendered preview, headed by a "Preview
# (click to edit)" toggle. The toggle (or a click on the preview) reveals a
# formatting toolbar and the textarea below it; the preview then updates live, rendered server-side by
# the same Redcarpet renderer the site uses (MarkdownEditorHelper,
# admin/markdown_editor.js).
#
# The stored value is still the raw textarea text: the toolbar only inserts
# markdown at the cursor, so existing hand-written HTML in a field survives an
# edit untouched.
#
#   = f.input :show_description, as: :markdown, input_html: { rows: 4 }
#   = f.input :confirmation_message, as: :markdown, preview: 'email'
#
#   = f.input :confirmation_message, as: :markdown, preview: 'email',
#             sample: { kind: 'production_confirmation', production_id: production.id }
#
# preview: a MarkdownEditorHelper::MARKDOWN_PREVIEW_FLAVORS key (default 'web').
# sample:  adds "Send sample email" to the header (MarkdownEditorHelper#markdown_editor).
class MarkdownInput < SimpleForm::Inputs::TextInput
  def input(wrapper_options = nil)
    # A field with a validation error opens straight into the editor.
    template.markdown_editor(super, value: current_value, editor_id: editor_id, open: has_errors?,
                                    flavor: options.fetch(:preview, 'web'), sample: options[:sample])
  end

  private

  def current_value
    object.public_send(attribute_name) if object.respond_to?(attribute_name)
  end

  def editor_id
    "#{object_name}_#{attribute_name}_markdown_editor".parameterize(separator: '_')
  end
end
