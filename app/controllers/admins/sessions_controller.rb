class Admins::SessionsController < ApplicationController
  # Admin login and magic link verification
  # All admin management happens through Madmin at /madmin

  # Stricter limits for admin authentication
  rate_limit to: 3, within: 1.minute, name: "admin_sessions/short", only: :create,
    with: -> { redirect_to new_admins_session_path, alert: "Too many attempts. Please wait." }
  rate_limit to: 10, within: 1.hour, name: "admin_sessions/long", only: :create,
    with: -> { redirect_to new_admins_session_path, alert: "Too many attempts. Try again later." }
  rate_limit to: 5, within: 5.minutes, name: "admin_sessions/verify", only: :verify,
    with: -> { redirect_to new_admins_session_path, alert: "Too many verification attempts." }

  layout "admin_auth", only: [ :new, :create ]

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

    redirect_to "/madmin", notice: "Welcome back, admin!"
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to new_admins_session_path, alert: "Invalid or expired magic link"
  end

  def destroy
    session[:admin_id] = nil
    redirect_to root_path, notice: "Signed out successfully"
  end
end
