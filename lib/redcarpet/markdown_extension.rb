class Redcarpet::MarkdownExtension < Redcarpet::Markdown
  def render(markdown_text)
    super(markdown_text.nil? ? "" : markdown_text)
  end
end
