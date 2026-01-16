class ModelsController < ApplicationController
  before_action :authenticate_user!

  def index
    @models = Model.all
  end

  def show
    @model = Model.find(params[:id])
  end
end
