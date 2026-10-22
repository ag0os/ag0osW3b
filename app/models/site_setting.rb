class SiteSetting < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validate :copy_link_placeholder

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

  # Public prose belongs in Copy; interface labels stay in config/locales.
  COPY_FIELDS = {
    "tagline" => "Hero tagline",
    "hero_note" => "Hero margin note",
    "work_intro" => "Work intro",
    "writing_intro" => "Writing intro",
    "footer_pitch" => "Footer pitch",
    "consulting_heading" => "Consulting heading",
    "consulting_contact" => "Consulting contact line",
    "about_empty" => "About coming soon",
    "work_empty" => "Work coming soon",
    "writing_empty" => "Writing coming soon"
  }.freeze
  COPY_KEYS = COPY_FIELDS.keys.flat_map { |key| [ key, "#{key}_es" ] }.freeze
  SETTINGS_KEYS = %w[site_title email github_url linkedin_url theme_preset].freeze
  COPY_LINKS = { "footer_pitch" => "%{consulting_link}", "consulting_contact" => "%{linkedin_link}" }.freeze

  # Fallback values used until/unless overridden in the admin.
  DEFAULTS = {
    "site_title"   => "Agustin Calabrese",
    # The hero tagline and link-preview description, until overridden in admin.
    "tagline"      => "Senior Software Engineer. I build the systems that let agents build good software, across the whole SDLC.",
    # The note in the margin of the hero, in the visitor's chosen hand. The
    # rail is 7.5rem wide, so a note is a handful of words: marginalia, not a
    # paragraph that happens to live in the margin.
    "hero_note"    => "Thirteen years in audio first. Same job.",
    # Spanish copy is a sibling key read through SiteSetting.localized.
    # Missing rows use these defaults; saved blanks request English.
    "tagline_es"   => "Ingeniero de software senior. Construyo los sistemas que permiten a los agentes construir buen software, en todo el ciclo de desarrollo.",
    "hero_note_es" => "Trece años en audio primero. El mismo trabajo.",
    "work_intro" => "Most of my product work is private. Here's the public proof.",
    "writing_intro" => "Notes on AI-native workflows, agent orchestration, and product-minded engineering.",
    "footer_pitch" => "Open to roles building agent systems and AI-native products, and to %{consulting_link}.",
    "consulting_heading" => "Agustín Calabrese: agentic development and AI-native systems",
    "consulting_contact" => "Want to talk about your team? Get in touch on %{linkedin_link}.",
    "about_empty" => "About content coming soon.",
    "work_empty" => "Projects coming soon.",
    "writing_empty" => "First essays coming soon.",
    "work_intro_es" => "Casi todo mi trabajo de producto es privado. Esta es la prueba pública.",
    "writing_intro_es" => "Notas sobre flujos de trabajo AI-native, orquestación de agentes e ingeniería con mirada de producto.",
    "footer_pitch_es" => "Abierto a roles construyendo sistemas de agentes y productos AI-native, y a %{consulting_link}.",
    "consulting_heading_es" => "Agustín Calabrese: desarrollo con agentes y sistemas AI-native",
    "consulting_contact_es" => "¿Querés hablar de tu equipo? Escribime por %{linkedin_link}.",
    "about_empty_es" => "Muy pronto, más sobre mí.",
    "work_empty_es" => "Muy pronto, proyectos.",
    "writing_empty_es" => "Muy pronto, los primeros ensayos.",
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

    # A missing Spanish row uses its default; a saved blank requests English.
    # Ordinary settings still read through [] with blank-means-default behavior.
    def localized(key)
      return self[key] if I18n.locale == :en

      translated = COPY_FIELDS.key?(key.to_s) ? copy_translation(key) : self["#{key}_#{I18n.locale}"]
      translated.presence || self[key]
    end

    def untranslated?(key)
      I18n.locale == :es && copy_translation(key).blank?
    end

    def copy_translation(key)
      spanish_key = "#{key}_es"
      record = find_by(key: spanish_key)
      record ? record.value : DEFAULTS[spanish_key]
    end

    def []=(key, value)
      find_or_initialize_by(key: key.to_s).update(value: value)
    end

    # Merged view of defaults + any stored overrides, for the settings form.
    def all_settings
      DEFAULTS.merge(pluck(:key, :value).to_h.compact)
    end
  end

  private

  def copy_link_placeholder
    token = COPY_LINKS[key.to_s.delete_suffix("_es")]
    return if token.nil? || value.blank? || value.scan(token).size == 1

    errors.add(:value, "for #{key} must contain #{token} exactly once.")
  end
end
