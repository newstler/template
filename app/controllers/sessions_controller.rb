class SessionsController < ApplicationController
  # Short-term: prevent rapid-fire attempts
  rate_limit to: 5, within: 1.minute, name: "sessions/short", only: :create,
    with: -> { redirect_to new_session_path, alert: "Too many attempts. Please wait." }

  # Long-term: prevent sustained attacks
  rate_limit to: 20, within: 1.hour, name: "sessions/long", only: :create,
    with: -> { redirect_to new_session_path, alert: "Too many attempts. Try again later." }

  # Token verification also rate-limited
  rate_limit to: 10, within: 5.minutes, name: "sessions/verify", only: :verify,
    with: -> { redirect_to new_session_path, alert: "Too many verification attempts." }

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

    redirect_to root_path, notice: "Welcome back, #{user.name}!"
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to new_session_path, alert: "Invalid or expired magic link"
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_path, notice: "Signed out successfully"
  end
end
