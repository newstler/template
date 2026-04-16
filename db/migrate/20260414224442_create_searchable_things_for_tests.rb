class CreateSearchableThingsForTests < ActiveRecord::Migration[8.2]
  def change
    create_table :searchable_things, id: { type: :string, default: -> { "uuid7()" } } do |t|
      t.string :name, null: false
      t.text :description
      t.string :tags
      t.timestamps
    end
  end
end
