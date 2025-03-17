class Game < ApplicationRecord
  # アソシエーション
  has_many :game_words, dependent: :destroy
  has_many :words, through: :game_words

  # バリデーション
  validates :player_name, presence: true
  validates :score, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # スコープ
  scope :high_scores, -> { order(score: :desc) }
  scope :recent, -> { order(created_at: :desc) }
end
