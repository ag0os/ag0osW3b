require "test_helper"

# The Markdown renderer's Contract, as tests. Each test is named after an
# obligation in PRODUCT.md ("The Markdown renderer"), and asserts only on the
# HTML that comes out, never on how it is produced. MR-17 to MR-20 are the
# change request "a mark may span inline formatting", and MR-21 makes any input
# render.
class MarkdownRendererContractTest < ActiveSupport::TestCase
  cover "MarkdownRenderer*" if respond_to?(:cover)

  # --- What it renders ------------------------------------------------------

  test "MR-1 renders GitHub-flavoured Markdown" do
    html = render(<<~MD)
      **strong** *em* ~~struck~~ https://example.com www.example.org

      | a |
      |---|
      | 1 |

      - [ ] open
      - [x] done

      Claim.[^1]

      [^1]: Source.
    MD

    assert html.at_css("strong"), "strong"
    assert html.at_css("em"), "emphasis"
    assert html.at_css("del"), "strikethrough"
    assert html.at_css('a[href="https://example.com"]'), "bare URL autolink"
    assert html.at_css('a[href="http://www.example.org"]'), "www autolink"
    assert html.at_css("table td"), "table"
    assert_equal 2, html.css('li input[type="checkbox"][disabled]').size, "task list"
    assert html.at_css('input[type="checkbox"][checked]'), "checked task"
    assert html.at_css("sup a[href^='#fn']"), "footnote reference"
    assert html.at_css(".footnotes li"), "footnote"
  end

  test "MR-2 sets typographic punctuation" do
    assert_equal "“Quoted” – dashed…", text("\"Quoted\" -- dashed...")
  end

  test "MR-3 a single newline inside a paragraph is not a line break" do
    html = render("one\ntwo")

    assert_nil html.at_css("br")
    assert_equal 1, html.css("p").size
  end

  # --- Safety ---------------------------------------------------------------

  test "MR-4 raw HTML in the source never reaches the output" do
    html = render(<<~MD)
      <script>alert(1)</script>

      Hi <b onclick="x()">there</b> <img src=x onerror=alert(1)> <iframe src=x></iframe>

      <style>body { display: none }</style>
    MD

    assert_empty html.css("script, b, img, iframe, style")
    assert_empty html.xpath(".//@*[starts-with(name(), 'on')]")
    assert_includes html.text, "there", "the words between the tags stay"
  end

  test "MR-4 a raw HTML block is dropped whole, words included" do
    assert_not_includes render("<div>inside a block</div>").text, "inside"
  end

  test "MR-5 a link to a dangerous scheme loses its URL and keeps its text" do
    %w[ javascript:alert(1) JaVaScRiPt:alert(1) vbscript:x file:///etc/passwd data:text/html,x data:image/svg+xml,<svg> ].each do |url|
      link = render("[label](#{url})").at_css("a")

      assert_equal "", link["href"].to_s, url
      assert_equal "label", link.text, url
    end
  end

  test "MR-5 an image from a dangerous scheme loses its URL" do
    [ "javascript:alert(1)", "data:image/svg+xml,<svg>" ].each do |url|
      assert_equal "", render("![x](#{url})").at_css("img")["src"].to_s, url
    end
  end

  test "MR-5 the kept data: types are a prefix, so data:image/pngx keeps its URL too" do
    url = "data:image/pngx,x"

    assert_equal url, render("![x](#{url})").at_css("img")["src"]
    assert_equal url, render("[x](#{url})").at_css("a")["href"]
  end

  test "MR-5 a raster data: image keeps its URL, as an image or a link" do
    %w[ data:image/png;base64,AAAA data:image/gif;base64,AAAA data:image/jpeg;base64,AAAA
        data:image/webp;base64,AAAA DATA:IMAGE/PNG;base64,AAAA ].each do |url|
      assert_equal url, render("![x](#{url})").at_css("img")["src"], url
      assert_equal url, render("[x](#{url})").at_css("a")["href"], url
    end
  end

  test "MR-5 ordinary links keep their URL" do
    { "https://x.com/a" => "https://x.com/a", "mailto:a@b.c" => "mailto:a@b.c",
      "/writing/a" => "/writing/a", "#notes" => "#notes" }.each do |url, href|
      assert_equal href, render("[l](#{url})").at_css("a")["href"]
    end
  end

  test "MR-6 the output is trusted markup a view inserts as it is" do
    assert_predicate MarkdownRenderer.render("*x*"), :html_safe?
  end

  # --- Tables ---------------------------------------------------------------

  test "MR-7 every table sits in its own keyboard-reachable, labelled scroll region" do
    html = render("| a |\n|---|\n| 1 |\n\n| b |\n|---|\n| 2 |")
    regions = html.css(".table-scroll")

    assert_equal 2, regions.size
    regions.each do |region|
      assert_equal "0", region["tabindex"]
      assert_equal "region", region["role"]
      assert_predicate region["aria-label"].to_s.strip, :present?
      assert_equal [ "table" ], region.element_children.map(&:name)
    end
  end

  # --- Code -----------------------------------------------------------------

  test "MR-8 code blocks are highlighted with classes and never with inline styles" do
    html = render("```ruby\ndef greet\n  # hi\nend\n```")
    code = html.at_css("pre.highlight > code.language-ruby")

    assert code, "pre.highlight > code.language-ruby"
    assert code.at_css("span.k"), "a keyword carries its short token class"
    assert code.at_css("span.c1"), "a comment carries its short token class"
    assert_empty html.xpath(".//@style")
  end

  test "MR-8 a block with no language or an unknown one is still a highlight block, as plain text" do
    [ "```\nplain\n```", "```nosuchlang\nplain\n```", "    plain" ].each do |md|
      code = render(md).at_css("pre.highlight > code")

      assert code, md
      assert_empty code.css("span"), md
      assert_equal "plain\n", code.text, md
    end
  end

  test "MR-8 a block whose author named no language has no class on its code" do
    [ "```\nplain\n```", "    plain" ].each do |md|
      assert_nil render(md).at_css("pre.highlight > code")["class"], md
    end
  end

  test "MR-8 the pre carries no lang attribute" do
    [ "```ruby\nx = 1\n```", "```nosuchlang\nx\n```" ].each do |md|
      assert_empty render(md).css("pre[lang]"), md
    end
  end

  test "MR-9 code shows exactly what the author typed" do
    assert_equal "<b>x</b> & ==y==\n", render("```\n<b>x</b> & ==y==\n```").at_css("pre code").text
    assert_equal "<script>", render("`<script>`").at_css("code").text
    assert_empty render("```ruby\n<script>x</script>\n```").css("script")
  end

  # --- The mark -------------------------------------------------------------

  test "MR-10 ==phrase== becomes a mark wherever prose appears" do
    [ "I turn intent into ==working systems==.", "# ==Heading==", "> ==quoted==",
      "- ==listed==", "| ==cell== |\n|---|\n| x |", "*==inside emphasis==*",
      "[==inside a link==](https://x.com)" ].each do |md|
      assert_equal 1, render(md).css("mark").size, md
    end

    assert_equal "working systems", render("into ==working systems==.").at_css("mark").text
  end

  test "MR-10 a paragraph may hold several marks" do
    assert_equal %w[ one two ], render("==one== and ==two==").css("mark").map(&:text)
  end

  test "MR-11 a mark is never applied inside code" do
    [ "Compare `x ==y== z`.", "```ruby\nx ==y== z\n```", "    x ==y== z" ].each do |md|
      html = render(md)

      assert_empty html.css("mark"), md
      assert_includes html.at_css("code").text, "x ==y== z", md
    end
  end

  test "MR-12 equals signs with a space or an equals sign on their inner side are left as typed" do
    { "x == y" => "x == y", "a ==  == b" => "a == == b", "== spaced ==" => "== spaced ==",
      "====" => "====", "=====" => "=====", "========" => "========",
      "==open only" => "==open only" }.each do |md, shown|
      html = render(md)

      assert_empty html.css("mark"), md
      assert_equal shown, html.text.squish, md
    end

    assert_empty render("==\tx==").css("mark"), "a tab is ASCII whitespace"
  end

  test "MR-12 a non-breaking or other Unicode space counts as content and forms a mark" do
    [ "\u00A0", "\u2003" ].each do |space|
      assert_equal [ space ], render("==#{space}==").css("mark").map(&:text), space.inspect
      assert_equal "<mark>#{space}</mark>", MarkdownRenderer.mark("==#{space}==").to_s, space.inspect
    end
  end

  test "MR-13 marking never turns text into markup" do
    mark = render("==&lt;i&gt;x &amp; y==").at_css("mark")

    assert_empty mark.element_children
    assert_equal "<i>x & y", mark.text
  end

  test "MR-13 marking removes the equals signs and nothing else" do
    { "a ==b== c" => "a b c",
      "==a== and ==b==" => "a and b",
      "==a *b* c== d" => "a b c d" }.each do |md, shown|
      assert_equal shown, text(md), md
    end
  end

  test "MR-14 a mark never crosses a block boundary" do
    [ "==one\n\ntwo==", "- ==one\n- two==", "> ==one\n\ntwo==" ].each do |md|
      html = render(md)

      assert_empty html.css("mark"), md
      assert_equal 2, html.text.scan("==").size, md
    end
  end

  test "MR-14 a mark never crosses a block inside a tight list item" do
    md = "- ==a\n  ```\n  x\n  ```\n  b=="
    html = render(md)

    assert_empty html.css("mark"), md
    assert_equal 2, html.text.scan("==").size, md
  end

  # --- Plain strings ----------------------------------------------------------

  test "MR-15 marking a plain string escapes everything but the mark it adds" do
    marked = MarkdownRenderer.mark(%(<script>alert(1)</script> & "q" ==this== *not* `md`))
    html = fragment(marked)

    assert_predicate marked, :html_safe?
    assert_equal [ "mark" ], html.element_children.map(&:name)
    assert_equal "this", html.at_css("mark").text
    assert_equal %(<script>alert(1)</script> & "q" this *not* `md`), html.text
  end

  test "MR-15 a plain string escapes even a string already marked safe" do
    html = fragment(MarkdownRenderer.mark("<img src=x onerror=y> ==x==".html_safe))

    assert_empty html.css("img")
    assert_equal "<img src=x onerror=y> x", html.text
  end

  test "MR-15 a newline in a plain string is ordinary text, so a mark may span it" do
    assert_equal "<mark>one\ntwo</mark>", MarkdownRenderer.mark("==one\ntwo==").to_s
    assert_equal "one\ntwo", MarkdownRenderer.unmark("==one\ntwo==")
  end

  test "MR-15 a plain string keeps the same delimiter rule" do
    assert_not_includes MarkdownRenderer.mark("x == y"), "<mark>"
    assert_equal "", MarkdownRenderer.mark(nil)
  end

  test "MR-15 every pair in a plain string is marked, not only the first" do
    assert_equal "<mark>a</mark> and <mark>b</mark>", MarkdownRenderer.mark("==a== and ==b==").to_s
  end

  test "MR-16 unmark keeps the words, drops the marks and stays plain text" do
    unmarked = MarkdownRenderer.unmark("Senior engineer building ==AI-native workflows==, x == y.")

    assert_equal "Senior engineer building AI-native workflows, x == y.", unmarked
    assert_not_predicate unmarked, :html_safe?
    assert_equal "", MarkdownRenderer.unmark(nil)
  end

  test "MR-16 unmark drops every mark, not only the first" do
    assert_equal "a and b", MarkdownRenderer.unmark("==a== and ==b==")
  end

  # --- Change request: a mark may span inline formatting --------------------

  test "MR-17 a mark may span emphasis, strong and strikethrough, which stay inside it" do
    { "==a *b* c==" => "a <em>b</em> c",
      "==a **b** c==" => "a <strong>b</strong> c",
      "==a ~~b~~ c==" => "a <del>b</del> c",
      "==*whole*==" => "<em>whole</em>" }.each do |md, inside|
      assert_marked md, inside
    end
  end

  test "MR-17 a mark may span a link, which keeps its URL" do
    assert_marked "==a [b](https://x.com) c==", %(a <a href="https://x.com">b</a> c)
    assert_marked "==[whole](https://x.com)==", %(<a href="https://x.com">whole</a>)
    assert_marked "==see https://x.com now==", %(see <a href="https://x.com">https://x.com</a> now)
  end

  test "MR-17 a mark may span inline code, whose text stays literal" do
    assert_marked "==a `b` c==", "a <code>b</code> c"
    assert_marked "==a `==` c==", "a <code>==</code> c"
  end

  test "MR-17 a mark may span a line break" do
    assert_marked "==one\ntwo==", "one\ntwo"
    assert_equal 1, render("==one\\\ntwo==").css("mark > br").size
  end

  test "MR-17 a mark may span an image or a footnote reference" do
    image = render("==a ![i](https://x.com/i.png) c==").at_css("mark")
    footnote = render("==a claim[^1] here==\n\n[^1]: Source.").at_css("mark")

    assert image&.at_css("img[src='https://x.com/i.png']"), "the image sits inside the mark"
    assert footnote&.at_css("sup a[href^='#fn']"), "the footnote reference sits inside the mark"
  end

  test "MR-17 a mark that spans formatting still nests inside formatting" do
    mark = render("**lead ==a *b* c== tail**").at_css("strong > mark")

    assert mark, "the mark forms inside the strong"
    assert_equal "a <em>b</em> c", mark.inner_html
  end

  test "MR-17 a mark that spans formatting still never turns text into markup" do
    mark = render("==a *b* &lt;i&gt;c&lt;/i&gt;==").at_css("mark")

    assert mark, "the mark forms"
    assert_equal [ "em" ], mark.element_children.map(&:name)
    assert_equal "a b <i>c</i>", mark.text
  end

  test "MR-18 equals signs inside code never open or close a mark" do
    [ "==a `b== c`", "`a ==b` c==", "==a `==` c" ].each do |md|
      html = render(md)

      assert_empty html.css("mark"), md
      assert_equal 2, html.text.scan("==").size, md
    end
  end

  test "MR-19 a mark whose ends sit on either side of an element boundary does not form" do
    { "==a [b== c](https://x.com)" => "a", "[a ==b](https://x.com) c==" => "a",
      "==a *b== c*" => "em", "*a ==b* c==" => "em" }.each do |md, kept|
      html = render(md)

      assert_empty html.css("mark"), md
      assert_equal 2, html.text.scan("==").size, md
      assert html.at_css(kept), "#{md} keeps its #{kept}"
    end
  end

  test "MR-19 a stray delimiter inside an element does not stop the mark around it" do
    assert_marked "==a *b== c* d==", "a <em>b== c</em> d"
  end

  test "MR-20 an unpartnered delimiter stays as typed and the formatting is untouched" do
    { "==a *b*" => "==a b", "a *b* c==" => "a b c==" }.each do |md, shown|
      html = render(md)

      assert_empty html.css("mark"), md
      assert html.at_css("em"), md
      assert_equal shown, html.text.squish, md
    end
  end

  test "MR-20 delimiters pair one element at a time, by the mark rule" do
    assert_equal MarkdownRenderer.mark("==a b ==c==").to_s,
      "<mark>a b ==c</mark>"
    assert_marked "==a *b* ==c==", "a <em>b</em> ==c"
    assert_equal %w[ a b ], render("==*a*== and ==**b**==").css("mark").map(&:text)
  end

  # --- Any input renders ----------------------------------------------------

  test "MR-21 no input renders nothing" do
    [ nil, "", "  \n", "\u00A0", "\u00A0\n" ].each do |input|
      output = MarkdownRenderer.render(input)

      assert_equal "", output.to_s.strip, input.inspect
      assert_predicate output, :html_safe?, input.inspect
    end
  end

  test "MR-21 a string in another encoding renders as the text it encodes" do
    { "plain ==ascii==".dup.force_encoding("US-ASCII") => "plain ascii",
      "café ==latin==".encode("ISO-8859-1") => "café latin",
      "café ==bytes==".b => "café bytes",
      "plain ==utf7==".dup.force_encoding("UTF-7") => "plain utf7",
      "plain ==jp==".dup.force_encoding("ISO-2022-JP-2") => "plain jp" }.each do |input, shown|
      html = render(input)

      assert_equal shown, html.text.squish, input.encoding.name
      assert_equal 1, html.css("mark").size, input.encoding.name
    end
  end

  test "MR-21 the caller's string is never changed, and a frozen one is accepted" do
    source = "café ==bytes==".b.freeze

    assert_includes MarkdownRenderer.render(source), "café <mark>bytes</mark>"
    assert_equal Encoding::BINARY, source.encoding
    assert_equal "café ==bytes==".b, source
  end

  test "MR-21 bytes that are not valid text become replacement characters" do
    assert_equal "bad \u{FFFD} byte", text("bad \xFF byte".b)
  end

  test "MR-21 bytes invalid or undefined in the string's own encoding become replacement characters" do
    { "bad \x81".dup.force_encoding("Shift_JIS") => "bad \u{FFFD}",
      "bad \x81 byte".dup.force_encoding("Windows-1252") => "bad \u{FFFD} byte" }.each do |input, shown|
      assert_equal shown, text(input), input.encoding.name
    end
  end

  test "MR-20 omitted raw HTML between two equals signs does not make a delimiter" do
    html = assert_nothing_raised { render("=<i>=a== tail") }

    assert_empty html.css("mark")
    assert_equal "==a== tail", html.text.squish
  end

  test "MR-20 a delimiter never pairs across omitted raw HTML" do
    html = render("==a=<i>=rest")

    assert_empty html.css("mark")
    assert_equal "==a==rest", html.text.squish
  end

  test "MR-20 omitted raw HTML counts as one character inside a mark" do
    assert_equal "x y", render("==x <!-- c -->y==").at_css("mark")&.text
    assert_marked "==a=<i>==", "a=<!-- raw HTML omitted -->"
  end

  test "MR-20 an outer mark wins and the delimiters inside it stay as typed" do
    assert_marked "==a *==b==* c==", "a <em>==b==</em> c"
  end

  test "MR-20 a child element counts as one non-space character whatever it holds" do
    assert_equal 1, render("==` `==").css("mark").size
    assert_equal 1, render("==[](/x)==").css("mark").size
  end

  private
    def render(markdown)
      fragment(MarkdownRenderer.render(markdown))
    end

    def text(markdown)
      render(markdown).text.strip
    end

    def fragment(html)
      Nokogiri::HTML5.fragment(html.to_s)
    end

    # The source renders exactly one mark, with this markup inside it.
    def assert_marked(markdown, inner_html)
      marks = render(markdown).css("mark")

      assert_equal 1, marks.size, "#{markdown.inspect} renders one mark"
      assert_equal inner_html, marks.first.inner_html, markdown.inspect
    end
end
