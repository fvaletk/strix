class CreateAnswerChunks < ActiveRecord::Migration[8.1]
  def change
    create_table :answer_chunks do |t|
      t.references :answer, null: false, foreign_key: true
      t.references :chunk, null: false, foreign_key: true
      t.float :similarity, null: false
      t.integer :rank, null: false
      t.boolean :cited, null: false, default: false
      t.timestamps
    end
    add_index :answer_chunks, [ :answer_id, :rank ], unique: true
  end
end
