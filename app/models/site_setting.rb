class SiteSetting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  # Theme presets. Each ships a light and a dark mode; see themes.css.
  # Adding one here plus a [data-theme="..."] block in themes.css is the whole
  # of it — no component changes, no view changes.
  PRESETS = %w[workshop console spec terminal].freeze

  PRESET_LABELS = {
    "workshop" => "Workshop",
    "console"  => "Console",
    "spec"     => "Spec",
    "terminal" => "Terminal"
  }.freeze

  # Fallback values used until/unless overridden in the admin.
  DEFAULTS = {
    "site_title"   => "Agustin Calabrese",
    # ==phrase== marks a phrase; see MarkdownRenderer::MARK. The mark is the
    # site's emphasis primitive, so it lives in the content, not in a class.
    # The hyphen in AI-native is U+2011, a non-breaking hyphen. A marked phrase
    # that breaks mid-word gets two swipes with a hyphen stranded at the end of
    # the first, which reads as a mistake rather than as emphasis.
    "tagline"      => "Senior Software Engineer building ==AI‑native== software workflows and agent orchestration tools.",
    # The note in the margin of the hero, in the visitor's chosen hand. The
    # rail is 7.5rem wide, so a note is a handful of words: marginalia, not a
    # paragraph that happens to live in the margin.
    "hero_note"    => "Thirteen years in audio first. Same job.",
    # Spanish copy is a sibling key with the locale as suffix, read through
    # SiteSetting.localized. Absent, the English value is used.
    "tagline_es"   => "Ingeniero de software senior; construyo flujos de trabajo ==AI‑native== y herramientas de orquestación de agentes.",
    "hero_note_es" => "Trece años en audio primero. El mismo trabajo.",
    # The shell on the home page. See SHELL.md. The opening is the session
    # typed out on load, as `;`-separated commands; whoami is what the first
    # of them prints.
    "shell_opening"   => "whoami; cat proof; help",
    "shell_whoami"    => "Senior software engineer in San Isidro, Buenos Aires, GMT-3. Rails and backend systems, cloud, ==AI‑native delivery==. Thirteen years as a DJ, producer and sound engineer before that.",
    "shell_whoami_es" => "Ingeniero de software senior en San Isidro, Buenos Aires, GMT-3. Rails y sistemas backend, cloud, ==entrega AI‑native==. Antes de eso, trece años como DJ, productor e ingeniero de sonido.",
    "email"        => "agoos@hey.com",
    "github_url"   => "https://github.com/ag0os",
    "linkedin_url" => "https://www.linkedin.com/in/agustincalabrese",
    "theme_preset" => "workshop"
  }.freeze

  class << self
    # The site's default preset, rendered server-side before any JavaScript
    # runs. Guarded, because an unrecognised value would emit a data-theme that
    # matches no token block and leave every semantic role undefined.
    def theme_preset
      preset = self["theme_preset"].to_s
      PRESETS.include?(preset) ? preset : PRESETS.first
    end

    def [](key)
      record = find_by(key: key.to_s)
      record&.value.presence || DEFAULTS[key.to_s]
    end

    # The value for the current locale when one exists (`tagline_es` while
    # the locale is Spanish), else the plain key. English has no suffix, so
    # for :en this is the same as [].
    def localized(key)
      self["#{key}_#{I18n.locale}"].presence || self[key]
    end

    def []=(key, value)
      find_or_initialize_by(key: key.to_s).update(value: value)
    end

    # Merged view of defaults + any stored overrides, for the settings form.
    def all_settings
      DEFAULTS.merge(pluck(:key, :value).to_h.compact)
    end
  end
end
