class Teams::SubscriptionCancellationsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_team_admin!

  def create
    current_team.cancel_subscription!
    redirect_to team_billing_path(current_team), notice: t("controllers.teams.subscription_cancellations.create.notice")
  end

  def destroy
    current_team.resume_subscription!
    redirect_to team_billing_path(current_team), notice: t("controllers.teams.subscription_cancellations.destroy.notice")
  end
end
