class CreateDocuments < ActiveRecord::Migration[7.1]
  def change
    create_table :documents do |t|
      t.string :title, null: false
      t.string :source, null: false
      t.text :body, null: false

      t.timestamps
    end
  end
end
