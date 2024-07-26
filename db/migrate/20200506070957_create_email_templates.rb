class CreateEmailTemplates < ActiveRecord::Migration[6.0]
  def change
    create_table :email_templates do |t|
      t.string :name
      t.text :template
      t.integer :template_type_id
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :email_templates, :template_type_id
  end
end
