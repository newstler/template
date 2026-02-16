class CreateArticles < ActiveRecord::Migration[8.2]
  def change
    create_table :articles, force: true, id: { type: :string, default: -> { "uuid7()" } } do |t|
      t.references :team, null: false, foreign_key: true, type: :string
      t.references :user, null: false, foreign_key: true, type: :string
      t.string :title, null: false
      t.text :body
      t.timestamps
    end
  end
end
