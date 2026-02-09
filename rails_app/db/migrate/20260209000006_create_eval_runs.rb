class CreateEvalRuns < ActiveRecord::Migration[7.1]
  def change
    create_table :eval_runs do |t|
      t.string :kind, null: false
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.text :notes

      t.timestamps
    end

    add_index :eval_runs, [:kind, :started_at]
  end
end
