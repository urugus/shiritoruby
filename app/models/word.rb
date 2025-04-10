# == Schema Information
#
# Table name: words
#
#  id              :integer          not null, primary key
#  word            :string           not null
#  normalized_word :string           not null
#  description     :text
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  word_type       :string           default("method"), not null
#
# Indexes
#
#  index_words_on_normalized_word  (normalized_word) UNIQUE
#  index_words_on_word             (word) UNIQUE
#  index_words_on_word_type        (word_type)
#
class Word < ApplicationRecord
  # アソシエーション
  has_many :game_words, dependent: :destroy
  has_many :games, through: :game_words

  # バリデーション
  validates :word, presence: true, uniqueness: { case_sensitive: false }
  validates :normalized_word, presence: true, uniqueness: { case_sensitive: false }
  # description は任意
  validates :word, length: { minimum: 2 } # 2文字以上の単語のみ使用可能（要件より）
  validates :word_type, presence: true, inclusion: {
    in: %w[ method keyword class module gem ],
    message: "%{value} is not a valid word type"
  }

  # 単語タイプに関するスコープ
  scope :by_type, ->(type) { where(word_type: type) }
  scope :methods, -> { where(word_type: "method") }
  scope :keywords, -> { where(word_type: "keyword") }
  scope :classes, -> { where(word_type: "class") }
  scope :modules, -> { where(word_type: "module") }
  scope :gems, -> { where(word_type: "gem") }

  # 検索・フィルタに関するスコープ
  scope :by_first_letter, ->(letter) { where("LOWER(word) LIKE ?", "#{letter.downcase}%") }
  scope :unused_in_game, ->(game_id) {
    where.not(id: GameWord.where(game_id: game_id).select(:word_id))
  }

  # コールバック
  before_save :downcase_word

  private

  # 保存前に単語を小文字に変換し、normalized_wordを設定
  def downcase_word
    self.word = word.downcase if word.present?
    self.normalized_word = word.downcase if word.present?
  end
end
