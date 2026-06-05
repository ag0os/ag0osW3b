class CreateSections < ActiveRecord::Migration[8.1]
  def change
    create_table :sections do |t|
      t.string :key, null: false
      t.string :heading
      t.text :body
      t.boolean :visible, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :sections, :key, unique: true
    add_index :sections, :position
  end
end
