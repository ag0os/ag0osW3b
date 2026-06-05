class Section < ApplicationRecord
  PAGES = %w[home about work contact].freeze

  validates :key, presence: true, uniqueness: true
  validates :page, presence: true, inclusion: { in: PAGES }

  scope :visible, -> { where(visible: true) }
  scope :ordered, -> { order(:position, :id) }
  scope :for_page, ->(page) { where(page: page) }
end
