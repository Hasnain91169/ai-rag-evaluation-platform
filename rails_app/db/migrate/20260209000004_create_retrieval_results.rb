class CreateRetrievalResults < ActiveRecord::Migration[7.1]
  def change
    create_table :retrieval_results do |t|
      t.references :query_trace, null: false, foreign_key: true
      t.references :chunk, null: false, foreign_key: true
      t.integer :rank, null: false
      t.float :score, null: false

      t.timestamps
    end

    add_index :retrieval_results, [:query_trace_id, :rank], unique: true
  end
end
