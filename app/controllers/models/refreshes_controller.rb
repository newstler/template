class Models::RefreshesController < ApplicationController
  before_action :authenticate_admin!

  def create
    Model.refresh!
    redirect_to models_path, notice: "Models refreshed successfully"
  end
end
