class SiteSetting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  # Fallback values used until/unless overridden in the admin.
  DEFAULTS = {
    "site_title"   => "Agustin Calabrese",
    "tagline"      => "Senior Software Engineer building AI-native software workflows and agent orchestration tools.",
    "email"        => "agoos@hey.com",
    "github_url"   => "https://github.com/ag0os",
    "linkedin_url" => "https://www.linkedin.com/in/agustincalabrese"
  }.freeze

  class << self
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
