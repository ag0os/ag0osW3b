module Admin
  class SiteSettingsController < BaseController
    def index
      @settings = SiteSetting.all_settings
    end

    def update
      (params[:settings] || {}).each do |key, value|
        SiteSetting[key] = value
      end
      redirect_to admin_site_settings_path, notice: "Settings saved."
    end
  end
end
