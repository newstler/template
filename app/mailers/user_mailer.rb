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
end
