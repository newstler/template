# frozen_string_literal: true

module Teams
  class UpdateTeamTool < ApplicationTool
    description "Update the current team's settings (admin only)"

    annotations(
      title: "Update Team",
      read_only_hint: false,
      open_world_hint: false
    )

    arguments do
      optional(:name).filled(:string).description("The team's display name")
      optional(:default_currency).filled(:string).description('ISO 4217 currency code (e.g. "USD", "EUR")')
      optional(:country_code).filled(:string).description('ISO 3166 alpha-2 country code (e.g. "US", "DE")')
    end

    def call(name: nil, default_currency: nil, country_code: nil)
      require_user!

      membership = current_user.membership_for(current_team)
      unless membership&.admin?
        return error_response("Admin access required to update team", code: "forbidden")
      end

      updates = {}
      updates[:name] = name if name.present?
      updates[:default_currency] = default_currency if default_currency.present?
      updates[:country_code] = country_code if country_code.present?

      if updates.empty?
        return error_response("No updates provided", code: "no_updates")
      end

      current_team.update!(updates)

      success_response(
        {
          id: current_team.id,
          name: current_team.name,
          slug: current_team.slug,
          default_currency: current_team.default_currency,
          country_code: current_team.country_code,
          updated_at: format_timestamp(current_team.updated_at)
        },
        message: "Team updated successfully"
      )
    rescue ActiveRecord::RecordInvalid => e
      error_response(e.message, code: "validation_error")
    end
  end
end
