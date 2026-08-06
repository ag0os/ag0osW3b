class PostsController < SiteController
  def index
    @posts = Post.published.recent
  end

  def show
    @post = Post.published.find_by!(slug: params[:slug])
  end

  # Atom, so the "engineer subscribes or returns" path in PRODUCT.md has
  # something to subscribe to. Rendered without the site layout.
  def feed
    @posts = Post.published.recent.limit(25)
    render layout: false, content_type: "application/atom+xml"
  end
end
