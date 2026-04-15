require "test_helper"

class SearchableTest < ActiveSupport::TestCase
  setup do
    SearchableThing.delete_all
  end

  test "searchable_fields is declared on the class" do
    assert_equal %i[name description tags], SearchableThing.searchable_fields_list
  end

  test "searchable_table_name is derived from the model name" do
    assert_equal "searchable_things_fts", SearchableThing.searchable_table_name
  end

  test "creates an FTS row on save" do
    thing = SearchableThing.create!(name: "Welder", description: "Russian speaker", tags: "marine")
    result = SearchableThing.search("welder")
    assert_includes result, thing
  end

  test "finds by description content" do
    thing = SearchableThing.create!(name: "Widget", description: "Heavy-duty industrial equipment")
    result = SearchableThing.search("industrial")
    assert_includes result, thing
  end

  test "returns empty relation for blank query" do
    SearchableThing.create!(name: "Anything")
    assert_empty SearchableThing.search("")
    assert_empty SearchableThing.search(nil)
  end

  test "handles Cyrillic queries" do
    thing = SearchableThing.create!(name: "Сварщик", description: "Русскоговорящий")
    result = SearchableThing.search("сварщик")
    assert_includes result, thing
  end

  test "handles Turkish diacritics via tokenizer" do
    thing = SearchableThing.create!(name: "Çilingir", description: "Locksmith")
    result = SearchableThing.search("Cilingir") # without the cedilla
    assert_includes result, thing
  end

  test "removes from FTS on destroy" do
    thing = SearchableThing.create!(name: "Destroyme")
    thing.destroy
    assert_empty SearchableThing.search("destroyme")
  end

  test "updates FTS on update" do
    thing = SearchableThing.create!(name: "Original")
    thing.update!(name: "Renamed")
    assert_includes SearchableThing.search("renamed"), thing
    assert_empty SearchableThing.search("original")
  end

  test "search returns a composable ActiveRecord::Relation" do
    SearchableThing.create!(name: "Welder Alpha")
    SearchableThing.create!(name: "Welder Beta")
    relation = SearchableThing.search("welder")
    assert_kind_of ActiveRecord::Relation, relation
    assert_equal 1, relation.where("name LIKE ?", "%Alpha%").count
  end

  test "composes with an outer where scope and only returns matching rows" do
    tenant_a = SearchableThing.create!(name: "Welder Alpha", tags: "tenant_a")
    _tenant_b = SearchableThing.create!(name: "Welder Beta", tags: "tenant_b")

    relation = SearchableThing.where(tags: "tenant_a").search("welder")

    assert_includes relation, tenant_a
    assert_equal 1, relation.count
    assert(relation.all? { |thing| thing.tags == "tenant_a" })
  end

  test "handles FTS5 operator-looking payloads without raising" do
    thing = SearchableThing.create!(name: "Operator Widget", description: "NEAR FOO BAR")
    assert_nothing_raised do
      SearchableThing.search('operator* NEAR "bar"')
    end
    result = SearchableThing.search('operator NEAR bar')
    assert_includes result, thing
  end
end
