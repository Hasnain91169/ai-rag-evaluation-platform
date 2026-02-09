class AddCitedChunkIdsToModelResponses < ActiveRecord::Migration[7.1]
  def change
    add_column :model_responses, :cited_chunk_ids, :jsonb, null: false, default: []
  end
end
