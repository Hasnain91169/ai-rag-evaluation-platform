class AddBaseScoreToRetrievalResults < ActiveRecord::Migration[7.1]
  def up
    add_column :retrieval_results, :base_score, :float, null: false, default: 0.0
    execute "UPDATE retrieval_results SET base_score = score"
  end

  def down
    remove_column :retrieval_results, :base_score
  end
end
