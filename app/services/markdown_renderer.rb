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

  # ==phrase== marks a phrase the way a highlighter does. Every preset draws
  # the mark with its own instrument; see the --mark tokens in themes.css.
  #
  # The lookarounds keep it off "== " and " ==", so a line of ==== used as a
  # setext rule or an operator written in prose is left alone.
  MARK = /==(?=\S)(.+?)(?<=\S)==/

  # For plain strings that are not Markdown, like the tagline. Escapes first,
  # so the only markup that can come out of it is the <mark> this puts in.
  def self.mark(text)
    ERB::Util.html_escape(text.to_s).gsub(MARK) { "<mark>#{$1}</mark>" }.html_safe
  end

  # The same string with the marks taken out, for the places that take text
  # and not markup: <title>, meta description, the Atom feed. Without this the
  # tagline ships its own equals signs to every link preview.
  def self.unmark(text)
    text.to_s.gsub(MARK) { $1 }
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

  # Applied to the rendered tree rather than to the source, so ==this== inside
  # a code span or a fenced block stays literal: it is code there, not
  # emphasis. Text nodes are escaped before being reparsed, so nothing a
  # visitor or an author writes can turn into markup by going through here.
  def apply_marks(fragment)
    fragment.xpath(".//text()[not(ancestor::code) and not(ancestor::pre)]").each do |node|
      next unless node.content.match?(MARK)

      node.replace(self.class.mark(node.content))
    end
  end

  def highlight(html)
    fragment = Nokogiri::HTML5.fragment(html)
    wrap_tables(fragment)
    apply_marks(fragment)
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
