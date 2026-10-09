class LocalesController < SiteController
  def update
    if I18n.available_locales.map(&:to_s).include?(params[:locale])
      cookies.permanent[:locale] = { value: params[:locale], same_site: :lax, httponly: true }
    end

    redirect_back_or_to root_path, allow_other_host: false, status: :see_other
  end
end
