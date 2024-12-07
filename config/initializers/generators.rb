Rails.application.config.generators do |g|
  g.orm :active_record, primary_key_type: :string

  g.after_generate do |files|
    next if files.grep(/controller\.rb/).empty?

    controller_name = files.grep(/controller\.rb/).first.split('/').last.gsub('_controller.rb', '')

    Rails::Generators.invoke "scaffold_controller", [
      "api/v1/#{controller_name}",
      *ARGV.drop(1),
      "--api",
      "--force"
    ]
  end
end
