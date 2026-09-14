class HomeController < SiteController
  def show
    @sections = Section.for_page("home").visible.ordered
    @recent_posts = Post.published.recent.limit(3)

    # The shell's transcript: the scripted opening, plus one exchange when a
    # command arrived as a query parameter, which is how the form submits with
    # JavaScript off (see ShellController).
    @opening = Shell.opening
    @exchanges = params[:line].present? ? [ Shell.run(params[:line]) ] : []
  end
end
