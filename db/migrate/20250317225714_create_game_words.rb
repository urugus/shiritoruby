class CreateGameWords < ActiveRecord::Migration[8.0]
  def change
    create_table :game_words do |t|
      t.references :game, null: false, foreign_key: true
      t.references :word, null: false, foreign_key: true
      t.integer :turn, null: false

      t.timestamps
    end
  end
end
