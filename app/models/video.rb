class Video < ApplicationRecord
  belongs_to :genre
  belongs_to :format
  has_many :comments

  validates :title, presence: true
  validates :format, presence: true
end
