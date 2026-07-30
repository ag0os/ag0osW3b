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
    "tagline"      => "Senior Software Engineer building AI-native software workflows and agent orchestration tools.",
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

    def []=(key, value)
      find_or_initialize_by(key: key.to_s).update(value: value)
    end

    # Merged view of defaults + any stored overrides, for the settings form.
    def all_settings
      DEFAULTS.merge(pluck(:key, :value).to_h.compact)
    end
  end
end
