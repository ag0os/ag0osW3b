class PostsController < SiteController
  def index
    @posts = Post.published.recent
  end

  def show
    @post = Post.published.find_by!(slug: params[:slug])
  end
end
