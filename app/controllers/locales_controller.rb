class LocalesController < SiteController
  def update
    choice = params[:locale]
    choice = nil unless I18n.available_locales.map(&:to_s).include?(choice)
    if choice
      cookies.permanent[:locale] = { value: params[:locale], same_site: :lax, httponly: true }
    end

    redirect_to counterpart(choice), status: :see_other
  end

  private
    def counterpart(choice)
      uri = public_referrer
      path = helpers.public_page_path(uri.path, locale: choice) if uri
      return root_path(locale: choice) unless path

      uri.query ? "#{path}?#{uri.query}" : path
    end

    def public_referrer
      referer = url_from(request.referer)
      return unless referer
      return if referer.start_with?("//")

      uri = URI.parse(referer)
      return uri if uri.relative?
      return unless %w[http https].include?(uri.scheme) && uri.port == request.port && uri.userinfo.nil?

      uri
    end
end
