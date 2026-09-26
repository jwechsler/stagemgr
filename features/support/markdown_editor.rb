# Markdown-enabled fields sit in a collapsed editor under their preview once
# admin/markdown_editor.js runs (@javascript scenarios); rack_test sees them
# open. Open the field's editor, as a user would, before filling it in.
module MarkdownEditorSteps
  def fill_in_markdown(locator, with:)
    field = find_field(locator, visible: :all)
    unless field.visible?
      field.find(:xpath, 'ancestor::div[contains(concat(" ", @class, " "), " markdown-editor ")][1]')
           .find('.markdown-editor__toggle').click
    end
    fill_in(locator, with: with)
  end
end

World(MarkdownEditorSteps)
