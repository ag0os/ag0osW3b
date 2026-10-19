class Section < ApplicationRecord
  PAGES = %w[home about work contact consulting].freeze

  validates :key, presence: true, uniqueness: true
  validates :page, presence: true, inclusion: { in: PAGES }

  scope :visible, -> { where(visible: true) }
  scope :ordered, -> { order(:position, :id) }
  scope :for_page, ->(page) { where(page: page) }

  # The heading, note or body in the page's language: `body_es` while the
  # locale is Spanish, falling back to the English column when that is blank.
  # English has no suffix, so for :en this is the plain column.
  def localized(attribute)
    translation(attribute).presence || self[attribute]
  end

  # True when the page's language has no text of its own for this field, so
  # the English shows on a page in another language and says so with lang.
  def untranslated?(attribute)
    I18n.locale != :en && self[attribute].present? && translation(attribute).blank?
  end

  private
    def translation(attribute)
      column = "#{attribute}_#{I18n.locale}"
      self[column] if has_attribute?(column)
    end
end
