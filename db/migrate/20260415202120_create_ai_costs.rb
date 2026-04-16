class CreateAiCosts < ActiveRecord::Migration[8.2]
  def change
    create_table :ai_costs, force: true, id: { type: :string, default: -> { "uuid7()" } } do |t|
      t.references :team, null: true, foreign_key: true, type: :string
      t.references :user, null: true, foreign_key: true, type: :string
      t.string :cost_type, null: false
      t.string :model_id, null: false
      t.integer :input_tokens, default: 0
      t.integer :output_tokens, default: 0
      t.decimal :cost, precision: 10, scale: 6, default: 0.0
      t.string :trackable_type
      t.string :trackable_id
      t.timestamps
    end

    add_index :ai_costs, :cost_type
    add_index :ai_costs, [ :trackable_type, :trackable_id ]
    add_index :ai_costs, :created_at
  end
end
