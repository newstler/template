require "test_helper"

class TeamLanguageTest < ActiveSupport::TestCase
  test "belongs to team" do
    tl = team_languages(:team_one_english)
    assert_equal teams(:one), tl.team
  end

  test "belongs to language" do
    tl = team_languages(:team_one_english)
    assert_equal languages(:english), tl.language
  end

  test "active scope returns only active team languages" do
    active = TeamLanguage.active
    assert_includes active, team_languages(:team_one_english)
    assert_includes active, team_languages(:team_one_spanish)
  end

  test "allows deactivating any language" do
    tl = team_languages(:team_one_spanish)
    tl.update!(active: false)
    assert_not tl.active?
  end

  test "team active_language_codes returns active codes" do
    team = teams(:one)
    codes = team.active_language_codes
    assert_includes codes, "en"
    assert_includes codes, "es"
  end

  test "team translation_target_codes excludes specified locale" do
    team = teams(:one)
    targets = team.translation_target_codes(exclude: "en")
    assert_includes targets, "es"
    assert_not_includes targets, "en"
  end

  test "team enable_language! activates language" do
    team = teams(:two)
    spanish = languages(:spanish)
    team.enable_language!(spanish)
    assert_includes team.active_language_codes, "es"
  end

  test "team enable_language! reactivates deactivated language" do
    team = teams(:one)
    spanish = languages(:spanish)
    team.disable_language!(spanish)
    assert_not_includes team.active_language_codes, "es"
    team.enable_language!(spanish)
    assert_includes team.active_language_codes, "es"
  end

  test "team disable_language! deactivates language" do
    team = teams(:one)
    spanish = languages(:spanish)
    team.disable_language!(spanish)
    assert_not_includes team.active_language_codes, "es"
  end
end
