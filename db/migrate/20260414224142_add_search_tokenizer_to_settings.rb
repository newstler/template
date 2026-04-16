class AddSearchTokenizerToSettings < ActiveRecord::Migration[8.2]
  def change
    add_column :settings, :search_tokenizer, :string, default: "porter unicode61 remove_diacritics 2"
  end
end
