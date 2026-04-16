require "test_helper"

class TeamTest < ActiveSupport::TestCase
  test "requires a unique name" do
    I18n.with_locale(:en) do
      existing = teams(:one)
      blank = Team.new(slug: "test")
      assert_not blank.valid?
      assert_includes blank.errors[:name], "can't be blank"

      duplicate = Team.new(name: existing.name)
      assert_not duplicate.valid?
      assert_includes duplicate.errors[:name], "has already been taken"
    end
  end

  test "generates slug from name on create" do
    team = Team.new(name: "My Amazing Team")
    team.valid?
    assert_equal "my-amazing-team", team.slug
  end

  test "regenerates slug when name changes" do
    team = teams(:one)
    team.update!(name: "Totally New Name")
    assert_equal "totally-new-name", team.slug
  end

  test "generates suffixed slug when base slug is taken" do
    Team.create!(name: "Collision Test")
    team_two = teams(:two)
    team_two.update!(name: "Collision Test Extra")
    assert_equal "collision-test-extra", team_two.slug
  end

  test "handles slug collision on rename" do
    team_one = teams(:one)
    team_two = teams(:two)
    team_two.update!(name: "#{team_one.name} Plus")
    assert_equal "team-one-plus", team_two.slug
  end

  test "adds sequential suffix when transliterated slug collides" do
    # "Команда" and "команда" produce the same slug "komanda" but different names
    Team.create!(name: "Команда")
    team_two = Team.create!(name: "команда")
    assert_equal "komanda-2", team_two.slug
  end

  test "transliterates non-Latin names to ASCII slugs" do
    assert_equal "komanda", Team.new(name: "Команда").tap(&:valid?).slug
    assert_equal "equipe-francaise", Team.new(name: "Équipe Française").tap(&:valid?).slug
    assert_equal "uber-komanda", Team.new(name: "Über Команда").tap(&:valid?).slug
  end

  test "to_param returns slug" do
    team = teams(:one)
    assert_equal team.slug, team.to_param
  end

  test "default_currency must be a supported code, or nil" do
    I18n.with_locale(:en) do
      team = teams(:one)

      team.default_currency = "XYZ"
      assert_not team.valid?
      assert_includes team.errors[:default_currency], "is not included in the list"

      team.default_currency = "EUR"
      assert team.valid?

      team.default_currency = nil
      assert team.valid?
    end
  end

  test "default_currency defaults to USD on create" do
    team = Team.create!(name: "Currency Default Team")
    assert_equal "USD", team.default_currency
  end

  test "country_code must be a valid alpha-2 when set" do
    team = teams(:one)
    team.country_code = "DE"
    assert team.valid?
    team.country_code = "ZZ"
    assert_not team.valid?
    assert team.errors[:country_code].any?
  end

  test "generates api_key on create and regenerate_api_key! rotates it" do
    team = Team.create!(name: "API Key Team")
    assert_equal 64, team.api_key.length

    original = team.api_key
    team.regenerate_api_key!
    assert_not_equal original, team.api_key
    assert_equal 64, team.api_key.length
  end
end
