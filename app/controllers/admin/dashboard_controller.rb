module Admin
  class DashboardController < BaseController
    def show
      @posts_count     = Post.count
      @published_count = Post.published.count
      @sections_count  = Section.count
      @recent_posts    = Post.order(created_at: :desc).limit(5)
    end
  end
end
