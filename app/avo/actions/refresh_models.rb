class Avo::Actions::RefreshModels < Avo::BaseAction
  self.name = "Refresh Models"
  self.message = "Refresh AI models from RubyLLM registry"
  self.confirm_button_label = "Refresh"
  self.standalone = true

  def handle(query:, fields:, current_user:, resource:, **args)
    Model.refresh!

    succeed "Models refreshed successfully! Total models: #{Model.count}"
  end
end
