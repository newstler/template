require "test_helper"

class Teams::LanguagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @team = teams(:one)
    sign_in(@user)
  end

  test "index shows active team languages" do
    get team_languages_path(@team)
    assert_response :success
    assert_select "span", text: "English"
  end

  test "create adds language to team" do
    french = languages(:french)

    assert_difference -> { @team.team_languages.count }, 1 do
      post team_languages_path(@team), params: { language_id: french.id }
    end

    assert_redirected_to team_languages_path(@team)
    assert_includes @team.active_language_codes, "fr"
  end

  test "create triggers backfill job" do
    french = languages(:french)

    assert_enqueued_with(job: BackfillTranslationsJob) do
      post team_languages_path(@team), params: { language_id: french.id }
    end
  end

  test "destroy deactivates language" do
    spanish = languages(:spanish)

    delete team_language_path(@team, spanish)

    assert_redirected_to team_languages_path(@team)
    assert_not_includes @team.active_language_codes, "es"
  end

  test "destroy prevents removing last language" do
    # Remove Spanish first so English is the only one left
    delete team_language_path(@team, languages(:spanish))

    delete team_language_path(@team, languages(:english))

    assert_redirected_to team_languages_path(@team)
    assert_includes @team.active_language_codes, "en"
  end

  test "non-admin cannot access languages" do
    # User two is a member (not admin) of team two via user_one_team_two fixture
    # but user_one is owner of team_one, so let's test with user_two on team_two
    sign_in(users(:two))
    # User two is owner of team two, which works.
    # Instead, test with user_one on team_two (member role)
    sign_in(users(:one))
    get team_languages_path(teams(:two))
    assert_response :redirect
  end
end
