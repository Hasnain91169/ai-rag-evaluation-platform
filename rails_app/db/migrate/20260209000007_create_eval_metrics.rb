class CreateEvalMetrics < ActiveRecord::Migration[7.1]
  def change
    create_table :eval_metrics do |t|
      t.references :eval_run, null: false, foreign_key: true
      t.references :query_trace, foreign_key: true
      t.string :name, null: false
      t.float :value_numeric, null: false
      t.text :value_text

      t.timestamps
    end

    add_index :eval_metrics, [:eval_run_id, :name]
    add_index :eval_metrics, [:query_trace_id, :name]
  end
end
