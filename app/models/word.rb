class Word < ApplicationRecord
  # アソシエーション
  has_many :game_words, dependent: :destroy
  has_many :games, through: :game_words

  # バリデーション
  validates :word, presence: true, uniqueness: { case_sensitive: false }
  validates :normalized_word, presence: true, uniqueness: { case_sensitive: false }
  # description は任意
  validates :word, length: { minimum: 2 } # 2文字以上の単語のみ使用可能（要件より）

  # スコープ
  scope :by_first_letter, ->(letter) { where("LOWER(word) LIKE ?", "#{letter.downcase}%") }
  scope :unused_in_game, ->(game_id) {
    where.not(id: GameWord.where(game_id: game_id).select(:word_id))
  }

  # コールバック
  before_save :downcase_word

  private

  # 保存前に単語を小文字に変換
  def downcase_word
    self.word = word.downcase if word.present?
  end
end
