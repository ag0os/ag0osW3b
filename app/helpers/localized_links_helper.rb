module LocalizedLinksHelper
  # Only call with rendered, sanitised Markdown; this preserves its markup.
  def localized_links(html)
    fragment = Nokogiri::HTML5.fragment(html)
    fragment.css("a[href]").each do |anchor|
      anchor["href"] = localized_href(anchor["href"])
    end
    fragment.to_html.html_safe
  end

  def public_page_path(path, locale:)
    route = Rails.application.routes.recognize_path(path)
    return unless %w[home pages posts].include?(route.fetch(:controller))

    url_for(route.merge(locale: locale || route[:locale]))
  rescue ActionController::RoutingError, ActionController::BadRequest
    nil
  end

  def localized_page_url(locale:)
    url_for(request.path_parameters.merge(locale: locale, only_path: false))
  end

  def open_graph_locale(locale)
    { en: "en_US", es: "es_AR" }.fetch(locale)
  end

  private
    def localized_href(href)
      return href unless href.start_with?("/") && !href.start_with?("//")

      uri = URI.parse(href)
      path = public_page_path(uri.path, locale: locale)
      return href unless path

      href.sub(uri.path, path)
    rescue URI::InvalidURIError
      href
    end
end
