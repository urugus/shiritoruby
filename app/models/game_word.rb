class GameWord < ApplicationRecord
  # アソシエーション
  belongs_to :game
  belongs_to :word

  # バリデーション
  validates :turn, presence: true, numericality: { only_integer: true, greater_than: 0 }

  # ゲーム内での単語の一意性を確保
  validates :word_id, uniqueness: { scope: :game_id, message: "は既にこのゲームで使用されています" }

  # スコープ
  scope :by_turn_order, -> { order(turn: :asc) }
end
