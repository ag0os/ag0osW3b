module Admin
  class SiteSettingsController < BaseController
    def index
      @settings = SiteSetting.all_settings.slice(*SiteSetting::SETTINGS_KEYS)
    end

    def update
      params.fetch(:settings, ActionController::Parameters.new).permit(*SiteSetting::SETTINGS_KEYS).each do |key, value|
        SiteSetting[key] = value
      end
      redirect_to admin_site_settings_path, notice: "Settings saved."
    end
  end
end
