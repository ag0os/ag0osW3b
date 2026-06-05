class Post < ApplicationRecord
  enum :status, { draft: 0, published: 1 }

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/, message: "must be lowercase words separated by hyphens" }
  validates :body, presence: true

  before_validation :generate_slug, on: :create
  before_save :sync_published_at

  scope :published, -> { where(status: :published).where.not(published_at: nil) }
  scope :recent, -> { order(published_at: :desc, created_at: :desc) }

  def to_param = slug

  def tag_list
    tags.to_s.split(",").map(&:strip).reject(&:blank?)
  end

  private

  def generate_slug
    self.slug = title.to_s.parameterize if slug.blank? && title.present?
  end

  def sync_published_at
    if published? && published_at.blank?
      self.published_at = Time.current
    elsif draft?
      self.published_at = nil
    end
  end
end
