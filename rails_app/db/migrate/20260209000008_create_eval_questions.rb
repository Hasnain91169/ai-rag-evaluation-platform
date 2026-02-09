class CreateEvalQuestions < ActiveRecord::Migration[7.1]
  def change
    create_table :eval_questions do |t|
      t.text :question_text, null: false
      t.text :expected_answer, null: false
      t.integer :gold_chunk_ids, array: true, default: [], null: false

      t.timestamps
    end

    add_index :eval_questions, :question_text, unique: true
  end
end
