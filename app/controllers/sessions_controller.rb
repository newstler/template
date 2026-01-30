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
    # Show login form
  end

  def create
    email = params.expect(session: :email)[:email]
    user = User.find_by(email: email)

    # Create user if doesn't exist (first magic link creates the account)
    unless user
      user = User.create!(
        email: email,
        name: email.split("@").first.titleize # Default name from email
      )
    end

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

    redirect_to after_login_path(user, params[:team]), notice: t("controllers.sessions.verify.notice", name: user.name)
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
    # If invited to a team, go there
    if invited_team_slug.present?
      team = Team.find_by(slug: invited_team_slug)
      return team_root_path(team) if team && user.member_of?(team)
    end

    teams = user.teams

    if Team.multi_tenant?
      case teams.count
      when 0
        team = create_personal_team(user)
        team_root_path(team)
      when 1
        team_root_path(teams.first)
      else
        teams_path
      end
    else
      # Single-tenant: auto-join or create the one team
      team = Team.first || create_personal_team(user)

      unless user.member_of?(team)
        user.memberships.create!(team: team, role: "member")
      end

      team_root_path(team)
    end
  end

  def create_personal_team(user)
    team = Team.create!(name: "#{user.name || user.email.split('@').first}'s Team")
    team.memberships.create!(user: user, role: "owner")
    team
  end
end
