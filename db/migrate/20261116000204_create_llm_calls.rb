class CreateLlmCalls < ActiveRecord::Migration[8.1]
  def change
    create_table :llm_calls do |t|
      t.integer :purpose, null: false
      t.string :model, null: false
      t.integer :input_tokens
      t.integer :output_tokens
      t.integer :thinking_tokens
      t.integer :latency_ms
      t.integer :status, null: false
      t.text :error_message
      t.references :subject, polymorphic: true

      t.timestamps
    end
  end
end
