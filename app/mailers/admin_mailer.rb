class AdminMailer < ApplicationMailer
  def magic_link(admin)
    @admin = admin
    @token = admin.generate_magic_link_token
    @magic_link_url = admins_verify_magic_link_url(token: @token)

    mail(
      to: @admin.email,
      subject: t(".subject")
    )
  end
end
