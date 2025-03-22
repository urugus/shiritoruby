class CreateGames < ActiveRecord::Migration[8.0]
  def change
    create_table :games do |t|
      t.string :player_name, null: false
      t.integer :score, null: false

      t.timestamps
    end
  end
end
