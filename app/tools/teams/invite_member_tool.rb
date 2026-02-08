# frozen_string_literal: true

module Teams
  class InviteMemberTool < ApplicationTool
    description "Invite a user to join the current team (admin only)"

    annotations(
      title: "Invite Team Member",
      read_only_hint: false,
      open_world_hint: false
    )

    arguments do
      required(:email).filled(:string).description("Email address of the user to invite")
    end

    def call(email:)
      require_user!

      membership = current_user.membership_for(current_team)
      unless membership&.admin?
        return error_response("Admin access required to invite members", code: "forbidden")
      end

      user = User.find_or_initialize_by(email: email)
      if user.new_record?
        user.name = email.split("@").first.titleize
        user.save!
      end

      if user.member_of?(current_team)
        return error_response("User is already a member of this team", code: "already_member")
      end

      token = user.signed_id(purpose: :magic_link, expires_in: 7.days)
      invite_url = Rails.application.routes.url_helpers.verify_magic_link_url(
        token: token,
        team: current_team.slug,
        invited_by: current_user.id,
        host: Rails.application.config.action_mailer.default_url_options[:host]
      )

      UserMailer.team_invitation(user, current_team, current_user, invite_url).deliver_later

      success_response(
        {
          email: user.email,
          team_slug: current_team.slug,
          invitation_sent: true
        },
        message: "Invitation sent to #{email}"
      )
    rescue ActiveRecord::RecordInvalid => e
      error_response(e.message, code: "validation_error")
    end
  end
end
