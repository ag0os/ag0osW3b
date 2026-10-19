class AddSpanishToSections < ActiveRecord::Migration[8.1]
  def change
    add_column :sections, :heading_es, :string
    add_column :sections, :note_es, :string
    add_column :sections, :body_es, :text
  end
end
