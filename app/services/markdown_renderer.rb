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
    @text = text.to_s.dup
    @text.force_encoding(Encoding::UTF_8) if @text.encoding == Encoding::BINARY
    @text = begin
      @text.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    rescue Encoding::ConverterNotFoundError
      @text.force_encoding(Encoding::UTF_8)
    end.scrub
  end

  # ==phrase== marks a phrase the way a highlighter does. Every preset draws
  # the mark with its own instrument; see the --mark tokens in themes.css.
  #
  # The lookarounds keep a space or = off the inner side of each delimiter,
  # so a run of = or an operator written in prose is left alone.
  MARK = /==(?=[^\s=])(.+?)(?<=[^\s=])==/m

  # Everything else counts as one inline character when pairing delimiters.
  BLOCKS = %w[ p h1 h2 h3 h4 h5 h6 blockquote ul ol li table thead tbody tr th td div hr pre ].freeze

  # For plain strings that are not Markdown, like the tagline. Escapes first,
  # so the only markup that can come out of it is the <mark> this puts in.
  def self.mark(text)
    ERB::Util.html_escape(String.new(text.to_s)).gsub(MARK) { "<mark>#{$1}</mark>" }.html_safe
  end

  # The same string with the marks taken out, for the places that take text
  # and not markup: <title>, meta description, the Atom feed. Without this the
  # tagline ships its own equals signs to every link preview.
  def self.unmark(text)
    text.to_s.gsub(MARK) { $1 }
  end

  def render
    return "".html_safe if @text.blank?

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

  # Each inline element is atomic here; its own delimiters are considered
  # separately. Moving the existing nodes keeps decoded text out of HTML parsing.
  def apply_marks(element)
    return if %w[ code pre ].include?(element.name)

    children = element.children.to_a
    children.chunk { |node| BLOCKS.include?(node.name) }.each do |block, nodes|
      mark_inline(nodes) unless block
    end
    children.select { |child| child.element? && child.parent == element }.each { |child| apply_marks(child) }
  end

  def mark_inline(nodes)
    positions = []
    text = nodes.map do |node|
      content = node.text? ? node.content : "\uFFFC"
      content.length.times { |offset| positions << [ node, offset ] }
      content
    end.join

    matches = text.enum_for(:scan, MARK).map { Regexp.last_match }
    matches.reverse_each do |match|
      first, start = positions[match.begin(0)]
      last, finish = positions[match.end(0) - 1]
      wrap_mark(first, start, last, finish + 1)
    end
  end

  def wrap_mark(first, start, last, finish)
    mark = first.document.create_element("mark")
    first.add_next_sibling(mark)
    if first == last
      mark.add_child(Nokogiri::XML::Text.new(first.content[start + 2...finish - 2], first.document))
      mark.add_next_sibling(Nokogiri::XML::Text.new(first.content[finish..], first.document))
    else
      mark.add_child(Nokogiri::XML::Text.new(first.content[start + 2..], first.document))
      node = mark.next_sibling
      until node == last
        following = node.next_sibling
        mark.add_child(node)
        node = following
      end
      mark.add_child(Nokogiri::XML::Text.new(last.content[...finish - 2], last.document))
      last.content = last.content[finish..]
    end
    first.content = first.content[...start]
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
