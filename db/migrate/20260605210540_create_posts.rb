class CreatePosts < ActiveRecord::Migration[8.1]
  def change
    create_table :posts do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.text :body
      t.text :excerpt
      t.integer :status, null: false, default: 0
      t.datetime :published_at
      t.string :tags

      t.timestamps
    end
    add_index :posts, :slug, unique: true
    add_index :posts, [ :status, :published_at ]
  end
end
