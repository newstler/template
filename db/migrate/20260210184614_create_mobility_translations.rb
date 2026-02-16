class CreateMobilityTranslations < ActiveRecord::Migration[8.2]
  def change
    create_table :mobility_string_translations, force: true, id: { type: :string, default: -> { "uuid7()" } } do |t|
      t.string :locale, null: false
      t.string :key, null: false
      t.string :value
      t.string :translatable_id, null: false
      t.string :translatable_type, null: false
      t.timestamps
    end

    add_index :mobility_string_translations,
      [ :translatable_id, :translatable_type, :locale, :key ],
      unique: true,
      name: :index_mobility_string_translations_on_keys
    add_index :mobility_string_translations,
      [ :translatable_id, :translatable_type, :key ],
      name: :index_mobility_string_translations_on_translatable_attribute
    add_index :mobility_string_translations,
      [ :translatable_type, :key, :value, :locale ],
      name: :index_mobility_string_translations_on_query_keys

    create_table :mobility_text_translations, force: true, id: { type: :string, default: -> { "uuid7()" } } do |t|
      t.string :locale, null: false
      t.string :key, null: false
      t.text :value
      t.string :translatable_id, null: false
      t.string :translatable_type, null: false
      t.timestamps
    end

    add_index :mobility_text_translations,
      [ :translatable_id, :translatable_type, :locale, :key ],
      unique: true,
      name: :index_mobility_text_translations_on_keys
    add_index :mobility_text_translations,
      [ :translatable_id, :translatable_type, :key ],
      name: :index_mobility_text_translations_on_translatable_attribute
  end
end
