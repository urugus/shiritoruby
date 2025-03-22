class CreateWords < ActiveRecord::Migration[8.0]
  def change
    create_table :words do |t|
      t.string :word, null: false
      t.string :normalized_word, null: false
      t.text :description

      t.timestamps
    end

    add_index :words, :word, unique: true
    add_index :words, :normalized_word, unique: true
  end
end
