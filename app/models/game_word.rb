# == Schema Information
#
# Table name: game_words
#
#  id         :integer          not null, primary key
#  game_id    :integer          not null
#  word_id    :integer          not null
#  turn       :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_game_words_on_game_id  (game_id)
#  index_game_words_on_word_id  (word_id)
#
# Foreign Keys
#
#  game_id  (game_id => games.id)
#  word_id  (word_id => words.id)
#
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
