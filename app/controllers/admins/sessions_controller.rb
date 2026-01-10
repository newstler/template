class Admins::SessionsController < ApplicationController
  # Admin login and magic link verification
  # All admin management happens through Avo at /avo

  def new
    # Show admin login form
  end

  def create
    email = params.expect(session: :email)[:email]
    admin = Admin.find_by(email: email)

    if admin
      # Send magic link to existing admin
      AdminMailer.magic_link(admin).deliver_later
      redirect_to new_admins_session_path, notice: "Check your email for a magic link!"
    else
      redirect_to new_admins_session_path, alert: "Admin not found. Only existing admins can log in."
    end
  end

  def verify
    admin = Admin.find_signed!(params[:token], purpose: :magic_link)
    session[:admin_id] = admin.id

    redirect_to "/avo", notice: "Welcome back, admin!"
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to new_admins_session_path, alert: "Invalid or expired magic link"
  end

  def destroy
    session[:admin_id] = nil
    redirect_to root_path, notice: "Signed out successfully"
  end
end
