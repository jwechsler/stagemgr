# Markdown-enabled fields sit in a collapsed editor under their preview
# (MarkdownEditorHelper, admin/markdown_editor.js). A browser scenario opens
# the editor as a user would. rack_test can't run the toggle's JavaScript, so
# there the (hidden) textarea is set directly: these scenarios are about the
# form's data, and the editor's own behaviour is covered by its specs.
module MarkdownEditorSteps
  def fill_in_markdown(locator, with:)
    field = find_field(locator, visible: :all)
    return fill_in(locator, with: with) if field.visible?
    return field.set(with) if Capybara.current_driver == :rack_test

    field.find(:xpath, 'ancestor::div[contains(concat(" ", @class, " "), " markdown-editor ")][1]')
         .find('.markdown-editor__toggle').click
    fill_in(locator, with: with)
  end
end

World(MarkdownEditorSteps)
