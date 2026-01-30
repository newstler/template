class Teams::MembersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_team_admin!, only: [ :new, :create, :destroy ]

  def index
    @memberships = current_team.memberships.includes(:user, :invited_by)
  end

  def new
    @invite_email = params[:email]
  end

  def create
    email = params[:email]
    user = User.find_or_initialize_by(email: email)

    if user.new_record?
      user.name = email.split("@").first.titleize
      user.save!
    end

    if user.member_of?(current_team)
      redirect_to team_members_path(current_team), alert: t("controllers.teams.members.already_member")
      return
    end

    token = user.signed_id(purpose: :magic_link, expires_in: 7.days)
    invite_url = verify_magic_link_url(token: token, team: current_team.slug, invited_by: current_user.id)

    UserMailer.team_invitation(user, current_team, current_user, invite_url).deliver_later

    redirect_to team_members_path(current_team), notice: t("controllers.teams.members.create.notice", email: email)
  end

  def destroy
    membership = current_team.memberships.find(params[:id])

    if membership.owner? && current_team.memberships.where(role: "owner").count == 1
      redirect_to team_members_path(current_team), alert: t("controllers.teams.members.cannot_remove_last_owner")
      return
    end

    membership.destroy
    redirect_to team_members_path(current_team), notice: t("controllers.teams.members.destroy.removed", name: membership.user.name)
  end
end
