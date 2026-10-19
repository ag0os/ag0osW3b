atom_feed(language: I18n.locale.to_s, url: feed_url) do |feed|
  feed.title(t("posts.feed_title", name: SiteSetting["site_title"]))
  feed.subtitle(MarkdownRenderer.unmark(SiteSetting.localized("tagline")))
  feed.updated(@posts.first&.published_at)

  @posts.each do |post|
    feed.entry(post, url: post_url(post), published: post.published_at, updated: post.updated_at) do |entry|
      entry.title(post.title)
      entry.summary(post.excerpt) if post.excerpt.present?
      entry.content(MarkdownRenderer.render(post.body), type: "html")

      entry.author { |author| author.name(SiteSetting["site_title"]) }
    end
  end
end
