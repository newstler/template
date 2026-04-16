require "test_helper"

class TeamLanguageTest < ActiveSupport::TestCase
  test "active scope returns only active team languages" do
    active = TeamLanguage.active
    assert_includes active, team_languages(:team_one_english)
    assert_includes active, team_languages(:team_one_spanish)
  end

  test "team active_language_codes returns active codes" do
    assert_equal %w[en es].sort, teams(:one).active_language_codes.sort
  end

  test "team translation_target_codes excludes specified locale" do
    targets = teams(:one).translation_target_codes(exclude: "en")
    assert_includes targets, "es"
    assert_not_includes targets, "en"
  end

  test "enable_language! activates and reactivates languages" do
    team = teams(:two)
    spanish = languages(:spanish)
    team.enable_language!(spanish)
    assert_includes team.active_language_codes, "es"

    team.disable_language!(spanish)
    assert_not_includes team.active_language_codes, "es"

    team.enable_language!(spanish)
    assert_includes team.active_language_codes, "es"
  end
end
