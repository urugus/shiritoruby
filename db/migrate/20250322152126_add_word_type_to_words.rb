class AddWordTypeToWords < ActiveRecord::Migration[8.0]
  def change
    add_column :words, :word_type, :string, null: false, default: 'method'
    add_index :words, :word_type
  end
end
