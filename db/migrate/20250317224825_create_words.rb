class CreateWords < ActiveRecord::Migration[8.0]
  def change
    create_table :words, id: :uuid do |t|
      t.string :word, null: false
      t.string :category, null: false
      t.text :description

      t.timestamps
    end

    add_index :words, :word, unique: true
  end
end
