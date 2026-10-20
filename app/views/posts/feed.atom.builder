feed_id_path = I18n.locale == :en ? "/feed" : "/#{I18n.locale}/feed"
content_language = I18n.locale == :en ? {} : { "xml:lang" => "en" }
atom_feed(language: I18n.locale.to_s, root_url: posts_url, url: feed_url(format: nil),
          id: "tag:#{request.host},2005:#{feed_id_path}") do |feed|
  feed.title(t("posts.feed_title", name: SiteSetting["site_title"]))
  feed.subtitle(MarkdownRenderer.unmark(SiteSetting.localized("tagline")))
  feed.updated(@posts.first&.published_at)

  @posts.each do |post|
    feed.entry(post, url: post_url(post), published: post.published_at, updated: post.updated_at) do |entry|
      entry.title(post.title, content_language)
      entry.summary(post.excerpt, content_language) if post.excerpt.present?
      entry.content(localized_links(markdown(post.body)), content_language.merge(type: "html"))

      entry.author { |author| author.name(SiteSetting["site_title"]) }
    end
  end
end
