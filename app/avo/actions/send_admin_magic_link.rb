class Avo::Actions::SendAdminMagicLink < Avo::BaseAction
  self.name = "Send Magic Link"
  self.message = "Send magic link email to selected admin(s)"
  self.confirm_button_label = "Send"

  def handle(query:, fields:, current_user:, resource:, **args)
    query.each do |admin|
      AdminMailer.magic_link(admin).deliver_later
    end

    succeed "Magic link(s) sent successfully!"
  end
end
