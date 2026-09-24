namespace :ruby_llm do
  desc "List code and data to change before upgrading to RubyLLM 2.0 (read-only; safe to run any time)"
  task upgrade_check: :environment do
    require "ruby_llm_upgrade_check"

    check = RubyLlmUpgradeCheck.new(root: Rails.root, connection: ActiveRecord::Base.connection)
    puts check.report
    exit 1 if check.blockers?
  end
end
