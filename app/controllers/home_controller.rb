class HomeController < SiteController
  def show
    @sections = Section.for_page("home").visible.ordered
    @recent_posts = Post.published.recent.limit(3)
  end
end
