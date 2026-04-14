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
end
