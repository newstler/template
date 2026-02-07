class SessionsController < ApplicationController
  # Short-term: prevent rapid-fire attempts
  rate_limit to: 5, within: 1.minute, name: "sessions/short", only: :create,
    with: -> { redirect_to new_session_path, alert: t("controllers.sessions.rate_limit.short") }

  # Long-term: prevent sustained attacks
  rate_limit to: 20, within: 1.hour, name: "sessions/long", only: :create,
    with: -> { redirect_to new_session_path, alert: t("controllers.sessions.rate_limit.long") }

  # Token verification also rate-limited
  rate_limit to: 10, within: 5.minutes, name: "sessions/verify", only: :verify,
    with: -> { redirect_to new_session_path, alert: t("controllers.sessions.rate_limit.verify") }

  def new
    redirect_to root_path if current_user
  end

  def create
    email = params.expect(session: :email)[:email]
    user = User.find_by(email: email)

    # Create user if doesn't exist (first magic link creates the account)
    # Name is collected during onboarding after first login
    user ||= User.create!(email: email)

    # Send magic link
    UserMailer.magic_link(user).deliver_later

    redirect_to new_session_path, notice: t("controllers.sessions.create.notice")
  end

  def verify
    user = User.find_signed!(params[:token], purpose: :magic_link)

    # Handle invitation params
    if params[:team].present?
      handle_team_invitation(user, params[:team], params[:invited_by])
    end

    session[:user_id] = user.id

    if user.onboarded?
      redirect_to after_login_path(user, params[:team]), notice: t("controllers.sessions.verify.notice", name: user.name)
    else
      ensure_team_exists(user, params[:team])
      redirect_to onboarding_path
    end
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to new_session_path, alert: t("controllers.sessions.verify.alert")
  end

  def destroy
    session[:user_id] = nil
    redirect_to new_session_path, notice: t("controllers.sessions.destroy.notice")
  end

  private

  def handle_team_invitation(user, team_slug, invited_by_id)
    team = Team.find_by(slug: team_slug)
    return unless team

    invited_by = User.find_by(id: invited_by_id)

    unless user.member_of?(team)
      user.memberships.create!(team: team, invited_by: invited_by, role: "member")
    end
  end

  def after_login_path(user, invited_team_slug = nil)
    # If invited to a team, go there (membership already created by handle_team_invitation)
    if invited_team_slug.present?
      team = Team.find_by(slug: invited_team_slug)
      return team_root_path(team) if team && user.member_of?(team)
    end

    teams = user.teams

    case teams.count
    when 0
      team = create_personal_team(user)
      team_root_path(team)
    when 1
      team_root_path(teams.first)
    else
      teams_path
    end
  end

  def ensure_team_exists(user, invited_team_slug = nil)
    return if user.teams.exists?

    create_personal_team(user)
  end

  def create_personal_team(user)
    team = Team.create!(name: "#{user.name || user.email.split('@').first}'s Team")
    team.memberships.create!(user: user, role: "owner")
    team
  end
end
