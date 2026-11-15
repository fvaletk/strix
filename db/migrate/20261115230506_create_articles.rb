class CreateArticles < ActiveRecord::Migration[8.1]
  def change
    create_table :articles do |t|
      t.references :user, null: false, foreign_key: true
      t.string :url, null: false
      t.integer :status, null: false, default: 0
      t.string :failure_reason
      t.string :title
      t.text :text
      t.integer :word_count
      t.boolean :tagging_failed, null: false, default: false

      t.timestamps
    end
    add_index :articles, [ :user_id, :url ], unique: true
  end
end
