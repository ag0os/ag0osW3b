module MarkdownHelper
  def markdown(text)
    MarkdownRenderer.render(text)
  end
end
