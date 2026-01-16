class Models::RefreshesController < ApplicationController
  before_action :authenticate_user!

  def create
    Model.refresh!
    redirect_to models_path, notice: "Models refreshed successfully"
  end
end
