class CreateQueryTraces < ActiveRecord::Migration[7.1]
  def change
    create_table :query_traces do |t|
      t.text :query_text, null: false
      t.bigint :user_id

      t.timestamps
    end

    add_index :query_traces, :created_at
  end
end
