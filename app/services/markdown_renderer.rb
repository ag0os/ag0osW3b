require "rouge"

# Renders Markdown to sanitized HTML, with class-based syntax highlighting
# (themeable via plain CSS) instead of Commonmarker's inline-style highlighter.
class MarkdownRenderer
  OPTIONS = {
    parse: { smart: true },
    render: { hardbreaks: false, unsafe: false, github_pre_lang: true },
    extension: {
      table: true, strikethrough: true, autolink: true,
      tagfilter: true, tasklist: true, footnotes: true
    }
  }.freeze

  def self.render(text)
    new(text).render
  end

  def initialize(text)
    @text = text.to_s
  end

  def render
    html = Commonmarker.to_html(@text, options: OPTIONS, plugins: { syntax_highlighter: nil })
    highlight(html).html_safe
  end

  private

  # Tables get a scroll container. Cells wrap, so a wide table is usually fine;
  # a single unbreakable token in a cell (an env var name, a long identifier)
  # is what bursts the column and gives the whole page a horizontal scrollbar
  # on a phone. tabindex makes the scroll region reachable from the keyboard,
  # which is required once a region scrolls.
  def wrap_tables(fragment)
    fragment.css("table").each do |table|
      wrapper = fragment.document.create_element("div")
      wrapper["class"] = "table-scroll"
      wrapper["tabindex"] = "0"
      wrapper["role"] = "region"
      wrapper["aria-label"] = "Table"
      table.replace(wrapper)
      wrapper.add_child(table)
    end
  end

  def highlight(html)
    fragment = Nokogiri::HTML5.fragment(html)
    wrap_tables(fragment)
    fragment.css("pre > code").each do |code|
      pre  = code.parent
      lang = pre["lang"].presence || code["class"].to_s[/language-(\w+)/, 1]
      lexer = (Rouge::Lexer.find(lang.to_s) if lang) || Rouge::Lexers::PlainText
      code.inner_html = Rouge::Formatters::HTML.new.format(lexer.lex(code.text))
      code["class"] = "language-#{lang}" if lang
      pre.remove_attribute("lang")
      pre["class"] = "highlight"
    end
    fragment.to_html
  end
end
