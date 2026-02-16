require "test_helper"

class TeamTest < ActiveSupport::TestCase
  test "validates presence of name" do
    team = Team.new(slug: "test")
    assert_not team.valid?
    assert_includes team.errors[:name], "can't be blank"
  end

  test "generates suffixed slug when base slug is taken" do
    Team.create!(name: "Collision Test")
    # Rename another team to force a slug collision
    team_two = teams(:two)
    team_two.update!(name: "Collision Test Extra")
    assert_equal "collision-test-extra", team_two.slug
  end

  test "generates slug from name on create" do
    team = Team.new(name: "My Amazing Team")
    team.valid?
    assert_equal "my-amazing-team", team.slug
  end

  test "validates uniqueness of name" do
    existing = teams(:one)
    team = Team.new(name: existing.name)
    assert_not team.valid?
    assert_includes team.errors[:name], "has already been taken"
  end

  test "regenerates slug when name changes" do
    team = teams(:one)
    original_slug = team.slug
    team.update!(name: "Totally New Name")
    assert_equal "totally-new-name", team.slug
    assert_not_equal original_slug, team.slug
  end

  test "handles slug collision on rename" do
    team_one = teams(:one)
    team_two = teams(:two)
    team_two.update!(name: "#{team_one.name} Plus")
    assert_equal "team-one-plus", team_two.slug
  end

  test "sequential suffix on slug collision" do
    # "Команда" and "команда" produce the same slug "komanda" but different names
    Team.create!(name: "Команда")
    team_two = Team.create!(name: "команда")
    assert_equal "komanda-2", team_two.slug
  end

  test "to_param returns slug" do
    team = teams(:one)
    assert_equal team.slug, team.to_param
  end

  test "transliterates Cyrillic names to ASCII slugs" do
    team = Team.new(name: "Команда")
    team.valid?
    assert_equal "komanda", team.slug
  end

  test "transliterates accented Latin names to ASCII slugs" do
    team = Team.new(name: "Équipe Française")
    team.valid?
    assert_equal "equipe-francaise", team.slug
  end

  test "transliterates mixed Cyrillic and Latin names" do
    team = Team.new(name: "Über Команда")
    team.valid?
    assert_equal "uber-komanda", team.slug
  end

  test "total_chat_cost returns sum of all chat costs" do
    team = teams(:one)
    assert_respond_to team, :total_chat_cost
  end

  test "has many memberships" do
    team = teams(:one)
    assert_respond_to team, :memberships
  end

  test "has many users through memberships" do
    team = teams(:one)
    assert_respond_to team, :users
  end

  test "has many chats" do
    team = teams(:one)
    assert_respond_to team, :chats
  end

  test "generates api_key on create" do
    team = Team.create!(name: "API Key Team")
    assert team.api_key.present?
    assert_equal 64, team.api_key.length
  end

  test "regenerate_api_key! updates api_key" do
    team = teams(:one)
    original_key = team.api_key
    team.regenerate_api_key!
    assert_not_equal original_key, team.api_key
    assert_equal 64, team.api_key.length
  end
end
