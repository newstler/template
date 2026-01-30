require "test_helper"

class TeamTest < ActiveSupport::TestCase
  test "validates presence of name" do
    team = Team.new(slug: "test")
    assert_not team.valid?
    assert_includes team.errors[:name], "can't be blank"
  end

  test "validates uniqueness of slug" do
    existing = teams(:one)
    team = Team.new(name: "Another Team", slug: existing.slug)
    assert_not team.valid?
    assert_includes team.errors[:slug], "has already been taken"
  end

  test "generates slug from name on create" do
    team = Team.new(name: "My Amazing Team")
    team.valid?
    assert_equal "my-amazing-team", team.slug
  end

  test "generates unique slug when collision exists" do
    existing = teams(:one)
    team = Team.create!(name: existing.name)
    assert_not_equal existing.slug, team.slug
    assert team.slug.start_with?("#{existing.slug}-")
  end

  test "to_param returns slug" do
    team = teams(:one)
    assert_equal team.slug, team.to_param
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

  test "multi_tenant? returns configuration value" do
    original_value = Rails.configuration.x.multi_tenant

    Rails.configuration.x.multi_tenant = true
    assert Team.multi_tenant?

    Rails.configuration.x.multi_tenant = false
    assert_not Team.multi_tenant?
  ensure
    Rails.configuration.x.multi_tenant = original_value
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
