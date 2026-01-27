# frozen_string_literal: true

namespace :mcp do
  # Controllers that are UI-only and don't need MCP equivalents
  EXCLUDED_CONTROLLERS = %w[
    sessions
    admins/sessions
    home
  ].freeze

  desc "Check MCP parity - list controllers without matching MCP tools"
  task parity: :environment do
    puts "Checking MCP parity...\n\n"

    # Get all controllers (excluding concerns, application, madmin, and UI-only)
    controller_files = Dir.glob(Rails.root.join("app/controllers/**/*_controller.rb"))
    controllers = controller_files.map do |f|
      relative = f.sub(Rails.root.join("app/controllers/").to_s, "")
      next if relative.start_with?("concerns/", "madmin/")
      next if relative == "application_controller.rb"

      controller_name = relative.sub("_controller.rb", "")
      next if EXCLUDED_CONTROLLERS.include?(controller_name)

      controller_name
    end.compact

    # Get all MCP tools
    tool_files = Dir.glob(Rails.root.join("app/tools/**/*_tool.rb"))
    tools = tool_files.map do |f|
      relative = f.sub(Rails.root.join("app/tools/").to_s, "")
      next if relative == "application_tool.rb"

      relative.sub("_tool.rb", "")
    end.compact

    # Map controllers to their likely MCP tools
    coverage = {}
    controllers.each do |controller|
      parts = controller.split("/")
      resource = parts.last.singularize

      # Look for matching tools
      matching_tools = tools.select { |t| t.include?(resource) || t.include?(parts.last) }
      coverage[controller] = matching_tools
    end

    # Report
    puts "Controller → MCP Tool Coverage\n"
    puts "=" * 50

    covered = 0
    uncovered = []

    coverage.each do |controller, matching_tools|
      if matching_tools.any?
        covered += 1
        puts "✅ #{controller}"
        matching_tools.each { |t| puts "   └─ #{t}" }
      else
        uncovered << controller
      end
    end

    puts "\n"
    if uncovered.any?
      puts "❌ Controllers without MCP tools:"
      uncovered.each { |c| puts "   - #{c}" }
    end

    puts "\n"
    puts "Summary: #{covered}/#{coverage.size} controllers have MCP tools"

    if uncovered.any?
      puts "\nTo add MCP tools for uncovered controllers:"
      puts "  bin/rails generate mcp:crud <resource_name>"
    end
  end

  desc "List all registered MCP tools"
  task tools: :environment do
    puts "Registered MCP Tools:\n\n"

    tools = ApplicationTool.descendants.sort_by(&:name)

    tools.each do |tool|
      admin = tool.respond_to?(:admin_only?) && tool.admin_only? ? " [ADMIN]" : ""
      puts "  #{tool.name}#{admin}"
      puts "    #{tool.description}" if tool.respond_to?(:description) && tool.description
      puts ""
    end

    puts "Total: #{tools.size} tools"
  end

  desc "List all registered MCP resources"
  task resources: :environment do
    puts "Registered MCP Resources:\n\n"

    resources = ApplicationResource.descendants.sort_by(&:name)

    resources.each do |resource|
      puts "  #{resource.name}"
      puts "    URI: #{resource.uri}" if resource.respond_to?(:uri) && resource.uri
      puts "    #{resource.description}" if resource.respond_to?(:description) && resource.description
      puts ""
    end

    puts "Total: #{resources.size} resources"
  end
end
