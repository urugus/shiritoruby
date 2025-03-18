class AddDurationToGames < ActiveRecord::Migration[8.0]
  def change
    add_column :games, :duration_seconds, :integer
  end
end