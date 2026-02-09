class CreateChunks < ActiveRecord::Migration[7.1]
  def change
    create_table :chunks do |t|
      t.references :document, null: false, foreign_key: true
      t.text :content, null: false
      t.integer :chunk_index, null: false
      t.jsonb :embedding, null: false, default: []

      t.timestamps
    end

    add_index :chunks, [:document_id, :chunk_index], unique: true
  end
end
