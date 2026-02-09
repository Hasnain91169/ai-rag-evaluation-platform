class CreatePromptTemplates < ActiveRecord::Migration[7.1]
  def change
    create_table :prompt_templates do |t|
      t.string :name, null: false
      t.string :version, null: false
      t.text :template, null: false
      t.boolean :active, null: false, default: false

      t.timestamps
    end

    add_index :prompt_templates, [:name, :version], unique: true
    add_index :prompt_templates, [:name, :active]
  end
end
