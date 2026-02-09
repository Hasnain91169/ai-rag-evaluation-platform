class CreateModelResponses < ActiveRecord::Migration[7.1]
  def change
    create_table :model_responses do |t|
      t.references :query_trace, null: false, foreign_key: true
      t.string :model_name, null: false
      t.string :prompt_version, null: false
      t.text :response_text, null: false
      t.float :latency_ms, null: false

      t.timestamps
    end

    add_index :model_responses, :query_trace_id, unique: true
  end
end
