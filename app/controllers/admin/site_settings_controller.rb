module Admin
  class SiteSettingsController < BaseController
    def index
      @settings = SiteSetting.all_settings.slice(*SiteSetting::SETTINGS_KEYS)
    end

    def update
      settings = params.expect(settings: SiteSetting::SETTINGS_KEYS)
      raise ActionController::BadRequest if params[:settings].keys.intersection(SiteSetting::SETTINGS_KEYS).size > settings.keys.size
      settings.each do |key, value|
        SiteSetting[key] = value
      end
      redirect_to admin_site_settings_path, notice: "Settings saved."
    end
  end
end
