class ModelsController < ApplicationController
  before_action :authenticate_user!

  def index
    @models = RubyLLM::ActiveRecord::Model.enabled.order(:provider, :name)
  end

  def show
    @model = RubyLLM::ActiveRecord::Model.enabled.find(params[:id])
  end
end
