class UserMailer < ApplicationMailer
  def magic_link(user)
    @user = user
    @token = user.generate_magic_link_token
    @magic_link_url = verify_magic_link_url(token: @token)

    mail(
      to: @user.email,
      subject: t(".subject")
    )
  end

  def team_invitation(user, team, invited_by, invite_url)
    @user = user
    @team = team
    @invited_by = invited_by
    @invite_url = invite_url

    mail(
      to: @user.email,
      subject: t(".subject", team_name: @team.name)
    )
  end
end
