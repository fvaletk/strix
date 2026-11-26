class CreateAnswers < ActiveRecord::Migration[8.1]
  def change
    create_table :answers do |t|
      t.references :question, null: false, foreign_key: true, index: { unique: true }
      t.text :text, null: false
      t.timestamps
    end
  end
end
