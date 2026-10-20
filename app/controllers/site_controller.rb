# Base controller for the public-facing site. The auth concern requires a
# session by default, so public pages opt out here.
#
# The path language wins, then the saved cookie, the browser and English.
# The admin does not go through here and stays English.
class SiteController < ApplicationController
  allow_unauthenticated_access
  around_action :switch_locale
  after_action :locale_cache_headers

  def default_url_options
    { path_params: { locale: locale } }
  end

  private
    def switch_locale(&action)
      I18n.with_locale(preferred_locale, &action)
    end

    def preferred_locale
      candidates = [ request.path_parameters[:locale], cookies[:locale], *accept_language ]
      candidates.map { |code| code.to_s.downcase.to_sym }.find { |code| I18n.available_locales.include?(code) } ||
        I18n.default_locale
    end

    def locale_cache_headers
      unless request.path_parameters.key?(:locale)
        headers["Vary"] = [ headers["Vary"], "Accept-Language" ].compact.join(", ")
      end
    end

    # "es-AR,es;q=0.9,en;q=0.8" => ["es", "es", "en"]. Browsers already list
    # these in order of preference, so the q values are not re-sorted.
    def accept_language
      request.env["HTTP_ACCEPT_LANGUAGE"].to_s.split(",").filter_map { |entry| entry.split(";").first.to_s.strip.split("-").first }
    end
end
