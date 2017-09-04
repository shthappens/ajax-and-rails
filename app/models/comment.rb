class Comment < ApplicationRecord
  belongs_to :video

  validates :title, presence: true
  validates :content, presence: true
  validates :video, presence: true
end
