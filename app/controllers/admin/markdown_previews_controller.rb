# Renders a markdown field's draft text for the live preview in the markdown
# editor (MarkdownEditorHelper). Uses the same renderer as the page or email
# the text ends up in, so what staff see is what patrons get. Nothing is stored.
class Admin::MarkdownPreviewsController < Admin::ApplicationController
  MAX_PREVIEW_LENGTH = 65_535 # a MySQL TEXT column; longer drafts can't be saved anyway

  def create
    authorize! :preview, :markdown
    text = params[:text].to_s
    return head :payload_too_large if text.length > MAX_PREVIEW_LENGTH

    flavor = params[:flavor].to_s
    flavor = 'web' unless MarkdownEditorHelper::MARKDOWN_PREVIEW_FLAVORS.key?(flavor)
    render html: text.blank? ? '' : helpers.render_markdown_preview(text, flavor)
  end
end
