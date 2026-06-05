class AddPageToSections < ActiveRecord::Migration[8.1]
  def change
    add_column :sections, :page, :string, null: false, default: "home"
    add_index :sections, [ :page, :position ]
  end
end
