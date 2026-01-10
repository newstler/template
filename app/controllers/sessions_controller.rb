class SessionsController < ApplicationController
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

    redirect_to new_session_path, notice: "Check your email for a magic link!"
  end

  def verify
    user = User.find_signed!(params[:token], purpose: :magic_link)
    session[:user_id] = user.id

    redirect_to home_path, notice: "Welcome back, #{user.name}!"
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to new_session_path, alert: "Invalid or expired magic link"
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_path, notice: "Signed out successfully"
  end
end
