class AddFirstLetterIndexToWords < ActiveRecord::Migration[8.0]
  def change
    add_index :words, "LOWER(SUBSTR(word, 1, 1))", name: 'index_words_on_first_letter'
  end
end
