# Rails Template for Ruby on Rails 8 with ULID, Devise, and Avo
# Usage: rails new myapp -m https://path/to/template.rb

# Helper method to check if we're using Rails from main branch
def edge_rails?
  ENV['RAILS_EDGE'] == 'true' || ask("Use Rails from main branch? (y/n)") == 'y'
end

# Setup Gemfile
gem_group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "dotenv"
end

gem_group :development do
  gem "web-console"
end

gem_group :test do
  gem "capybara"
  gem "selenium-webdriver"
end

# Add additional gems
gem "sqlite-ulid"
gem "devise", "~> 4.9"
gem "avo", ">= 3.2"
gem "tailwindcss-rails", "~> 4.0"

# If using edge Rails, update the Gemfile
if edge_rails?
  gsub_file "Gemfile", /gem "rails".*$/, 'gem "rails", github: "rails/rails", branch: "main"'
end

# Run bundle install
run "bundle install"

# Setup database configuration for ULID
create_file "config/database.yml", force: true do
  <<~YAML
    # SQLite. Versions 3.8.0 and up are supported.
    #   gem install sqlite3
    #
    #   Ensure the SQLite 3 gem is defined in your Gemfile
    #   gem "sqlite3"
    #
    default: &default
      adapter: sqlite3
      pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
      timeout: 5000
      extensions:
        - ulid

    development:
      <<: *default
      database: storage/development.sqlite3

    # Warning: The database defined as "test" will be erased and
    # re-generated from your development database when you run "rake".
    # Do not set this db to the same as development or production.
    test:
      <<: *default
      database: storage/test.sqlite3


    # Store production database in the storage/ directory, which by default
    # is mounted as a persistent Docker volume in config/deploy.yml.
    production:
      primary:
        <<: *default
        database: storage/production.sqlite3
      cache:
        <<: *default
        database: storage/production_cache.sqlite3
        migrations_paths: db/cache_migrate
      queue:
        <<: *default
        database: storage/production_queue.sqlite3
        migrations_paths: db/queue_migrate
      cable:
        <<: *default
        database: storage/production_cable.sqlite3
        migrations_paths: db/cable_migrate
  YAML
end

# Create SQLite initializer for ULID extension
create_file "config/initializers/sqlite.rb" do
  <<~RUBY
    # frozen_string_literal: true

    module SQLite3
      class Database
        alias_method :original_initialize_extensions, :initialize_extensions

        def initialize_extensions(extensions)
          # Convert extension names to actual paths
          extensions&.map! do |ext|
            case ext
            when "ulid"
              require "sqlite_ulid"
              SqliteUlid.ulid_loadable_path
            else
              ext
            end
          end

          original_initialize_extensions(extensions)
        end
      end
    end
  RUBY
end

# Configure generators to use string primary keys
create_file "config/initializers/generators.rb" do
  <<~RUBY
    Rails.application.config.generators do |g|
      g.orm :active_record, primary_key_type: :string
    end
  RUBY
end

# Override ApplicationRecord if it exists (for ULID setup)
# Note: This is handled by the generator configuration above

# Setup solid adapters
rails_command "solid_cache:install"
rails_command "solid_queue:install"
rails_command "solid_cable:install"

# Install Tailwind CSS
rails_command "tailwindcss:install"

# Create storage directory
empty_directory "storage"
create_file "storage/.keep"

# Install Devise
generate "devise:install"

# Create Devise User model with ULID
generate "devise", "User", "name:string"

# Modify the User migration to use ULID
user_migration = Dir.glob("db/migrate/*_devise_create_users.rb").first
if user_migration
  gsub_file user_migration, /create_table :users do/, <<~RUBY.strip
    create_table :users, force: true, id: false do |t|
      t.primary_key :id, :string, default: -> { "ULID()" }
  RUBY
end

# Create Admin model with Devise and ULID
generate "devise", "Admin"

# Modify the Admin migration to use ULID
admin_migration = Dir.glob("db/migrate/*_devise_create_admins.rb").first
if admin_migration
  gsub_file admin_migration, /create_table :admins do/, <<~RUBY.strip
    create_table :admins, force: true, id: false do |t|
      t.primary_key :id, :string, default: -> { "ULID()" }
  RUBY
end

# Install Avo
generate "avo:install"

# Create .rubocop.yml
create_file ".rubocop.yml" do
  <<~YAML
    inherit_gem:
      rubocop-rails-omakase: rubocop.yml

    AllCops:
      TargetRubyVersion: 3.3
      Exclude:
        - 'db/schema.rb'
        - 'vendor/**/*'
  YAML
end

# Create .github directory and workflows if requested
if yes?("Would you like to add GitHub Actions for CI? (y/n)")
  empty_directory ".github/workflows"
  create_file ".github/workflows/ci.yml" do
    <<~YAML
      name: CI
      on: [push, pull_request]
      jobs:
        test:
          runs-on: ubuntu-latest
          steps:
            - uses: actions/checkout@v4
            - name: Set up Ruby
              uses: ruby/setup-ruby@v1
              with:
                ruby-version: 3.3
                bundler-cache: true
            - name: Run tests
              run: bin/rails test
            - name: Run Rubocop
              run: bundle exec rubocop
            - name: Run Brakeman
              run: bundle exec brakeman
    YAML
  end
end

# Create Procfile.dev for development
create_file "Procfile.dev" do
  <<~PROCFILE
    web: bin/rails server
    css: bin/rails tailwindcss:watch
  PROCFILE
end

# Update routes
route 'devise_for :admins'
route 'devise_for :users'
route 'mount Avo::Engine, at: Avo.configuration.root_path'
route 'root "home#index"'

# Create a basic home controller and view
generate "controller", "home", "index", "--skip-routes"

# Update the home page view
create_file "app/views/home/index.html.erb", force: true do
  <<~ERB
    <div class="min-h-screen bg-gray-100">
      <div class="py-12">
        <div class="max-w-7xl mx-auto sm:px-6 lg:px-8">
          <div class="bg-white overflow-hidden shadow-sm sm:rounded-lg">
            <div class="p-6 bg-white border-b border-gray-200">
              <h1 class="text-3xl font-bold text-gray-900">Welcome to Rails!</h1>
              <p class="mt-2 text-gray-600">Your Rails application is running with ULID primary keys, Devise authentication, and Avo admin panel.</p>
              
              <div class="mt-6 space-y-2">
                <% if user_signed_in? %>
                  <p>Logged in as: <%= current_user.email %></p>
                  <%= link_to "Logout", destroy_user_session_path, method: :delete, class: "text-blue-600 hover:text-blue-800" %>
                <% else %>
                  <%= link_to "Login", new_user_session_path, class: "text-blue-600 hover:text-blue-800" %>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  ERB
end

# Add .cursor directory structure if requested
if yes?("Would you like to add Cursor AI configuration files? (y/n)")
  empty_directory ".cursor/rules"
  
  create_file ".cursor/rules/rails.mdc" do
    File.read(File.expand_path("../rails_rules_content.txt", __FILE__)) rescue <<~MDC
      # Rails 8 Development Guidelines
      
      ## 1. Rails 8 Core Features
      
      ** Prefer the command line utilities to manually generated code ** 
      e.g use `rails generate model` instead of creating a model from scratch
      
      ** IMPORTANT: Server Management **
      - Always use `bin/dev` to start the server (uses Procfile.dev)
      - Check logs after every significant change
      - Monitor development.log for errors and performance issues
      
      1. **Modern Infrastructure**
         - Use Thruster for asset compression and caching
         - Implement Kamal 2 for deployment orchestration
         - Utilize Solid Queue for background job processing
         - Leverage Solid Cache for caching
         - Use Solid Cable for real-time features
      
      2. **Database Best Practices**
         - Use ULID as the primary key
         - Use SQLite full-text search capabilities
         - Configure proper database extensions in database.yml
      
      3. **Controller Patterns**
         - Use `params.expect()` for safer parameter handling
         - Keep controllers RESTful and focused
         - Use service objects for complex business logic
    MDC
  end
end

# Run database setup
rails_command "db:create"
rails_command "db:migrate"

# Final instructions
puts "\n🎉 Rails application created successfully!"
puts "\nNext steps:"
puts "1. cd #{app_name}"
puts "2. Run 'bin/dev' to start the development server"
puts "3. Visit http://localhost:3000"
puts "\nFeatures included:"
puts "✓ Rails 8 with ULID primary keys"
puts "✓ SQLite with ULID extension"
puts "✓ Devise authentication (User and Admin models)"
puts "✓ Avo admin panel at /avo"
puts "✓ Tailwind CSS v4"
puts "✓ Solid adapters (Cache, Queue, Cable)"
puts "✓ Development tools (Rubocop, Brakeman, Debug)"
puts "\nHappy coding! 🚀" 