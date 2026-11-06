class CreateDailyInspirations < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_inspirations do |t|
      t.date :day, null: false, index: { unique: true }
      t.text :verse_text, null: false
      t.string :verse_reference, null: false
      t.text :verse_reflection
      t.jsonb :questions, null: false, default: []
      t.string :source, null: false, default: "ai"
      t.timestamps
    end
  end
end
