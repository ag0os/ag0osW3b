module MarkdownHelper
  def markdown(text)
    MarkdownRenderer.render(text)
  end

  # For single-line strings that are not Markdown: the tagline, a page lead.
  # Only ==phrase== is honoured, and everything else is escaped.
  def marked(text)
    MarkdownRenderer.mark(text)
  end

  # The same string with its marks removed, for anywhere that takes text
  # rather than markup: <title>, meta description, the feed.
  def unmarked(text)
    MarkdownRenderer.unmark(text)
  end
end
