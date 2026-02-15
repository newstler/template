class BackfillTranslationsJob < ApplicationJob
  def perform(team_id, target_locale)
    team = Team.find_by(id: team_id)
    return unless team

    translatable_models.each do |model_class|
      records = model_class.where(team_id: team.id)
      next if records.empty?

      jobs = records.map do |record|
        TranslateContentJob.new(model_class.name, record.id, I18n.default_locale.to_s, target_locale)
      end

      ActiveJob.perform_all_later(jobs)
    end
  end

  private

  def translatable_models
    Rails.autoloaders.main.eager_load
    ApplicationRecord.descendants.select { |klass|
      klass.include?(Translatable) && klass.column_names.include?("team_id")
    }
  end
end
