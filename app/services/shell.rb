# Interprets one line typed into the shell on the home page and decides what
# to print. See SHELL.md.
#
# It knows nothing about HTTP or HTML. A Result names a view under
# app/views/shell/ and carries its locals; the controller renders that as a
# Turbo Stream when JavaScript is on, and the home page renders the same
# result inline when it is off. The opening a visitor sees on load is a list
# of these too, run at render time from the shell_opening setting.
#
# Free text that matches no command lands in :unknown. That branch is where
# the FAQ matcher (v1) and the grounded model (v2) plug in.
class Shell
  MAX_LENGTH = 280

  # Commands the browser answers itself when JavaScript is on, because they
  # change presentation state that lives there (see shell_controller.js). The
  # server still recognises them so it can say so when JavaScript is off.
  CLIENT_SIDE = %w[theme light dark mode clear].freeze

  # Pages `open` can go to. ShellHelper#shell_pages maps each to its path.
  OPENABLE = %w[home about work writing contact].freeze

  # Everything a visitor can type, for Tab completion.
  COMMANDS = (%w[help whoami cat ls about work contact home writing open lang] + CLIENT_SIDE).freeze

  Result = Data.define(:line, :view, :locals) do
    def initialize(line:, view:, locals: {}) = super
  end

  def self.run(line) = new(line).run

  # The scripted session played on load: a `;`-separated list of commands in
  # the shell_opening setting, so the greeting is content and changes without
  # a deploy.
  def self.opening
    SiteSetting["shell_opening"].to_s.split(";").map(&:strip).reject(&:blank?).map { |line| run(line) }
  end

  attr_reader :line, :name, :arg

  def initialize(raw)
    @line = clean(raw)
    @name, @arg = @line.split(" ", 2)
    @name = @name.to_s.downcase
  end

  def run
    case name
    when "", "help", "?" then result(:help)
    when "whoami" then result(:whoami)
    when "cat" then cat(arg)
    when *Section::PAGES then cat(name)
    when "ls" then result(:ls, pages: Section::PAGES.index_with { |page| Section.for_page(page).visible.count }, posts: Post.published.count)
    when "writing", "posts", "blog" then result(:writing, posts: Post.published.recent.limit(5))
    when "open", "cd", "go" then open(arg)
    when "lang", "language", "idioma" then lang(arg)
    when *CLIENT_SIDE then result(:needs_js, name: name)
    else result(:unknown, line: line)
    end
  end

  private
    def result(view, **locals)
      Result.new(line: line, view: view, locals: locals)
    end

    def message(text)
      result(:message, text: text)
    end

    # Control characters become spaces (a pasted newline is not a command
    # separator), runs of spaces collapse, and the line is capped. Nothing
    # here is a security measure, since every view escapes what it prints; it
    # is what keeps the echoed line printable.
    def clean(raw)
      raw.to_s.gsub(/[[:cntrl:]]/, " ").squeeze(" ").strip[0, MAX_LENGTH]
    end

    # A page name prints the page; a section key prints that section; and a
    # key's suffix works too, so `cat proof` finds home_proof. `.md` and a
    # trailing slash are tolerated, since the help text calls these pages and
    # people will type them like files.
    def cat(target)
      key = target.to_s.downcase.strip.delete_suffix("/").delete_suffix(".md")
      return message(I18n.t("shell.cat.usage")) if key.blank?

      visible = Section.visible.ordered
      if Section::PAGES.include?(key)
        return result(:sections, sections: visible.for_page(key).to_a)
      end

      sections = visible.where(key: key).to_a
      sections = visible.select { |section| section.key.end_with?("_#{key}") } if sections.empty?
      return message(I18n.t("shell.cat.not_found", name: key)) if sections.empty?

      result(:sections, sections: sections)
    end

    def open(target)
      page = target.to_s.downcase.strip.delete_prefix("/").delete_suffix("/")
      page = "writing" if page == "posts"
      return message(I18n.t("shell.open.usage")) if page.blank?
      return message(I18n.t("shell.open.not_found", name: page)) unless OPENABLE.include?(page)

      result(:open, page: page)
    end

    def lang(target)
      names = I18n.available_locales.map { |locale| "#{locale} (#{I18n.t("shell.lang.names.#{locale}")})" }.join(", ")
      code = target.to_s.downcase.strip
      return message(I18n.t("shell.lang.current", name: I18n.t("shell.lang.names.#{I18n.locale}"), names: names)) if code.blank?

      locale = code.to_sym
      return message(I18n.t("shell.lang.unknown", name: code, names: names)) unless I18n.available_locales.include?(locale)

      result(:lang, locale: locale)
    end
end
