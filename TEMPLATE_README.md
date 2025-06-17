# Rails 8 Template with ULID, Devise, and Avo

This is a Rails application template that sets up a new Rails 8 project with modern best practices and useful defaults.

## Features

- **Rails 8** with optional edge (main branch) support
- **SQLite with ULID** - Uses ULID (Universally Unique Lexicographically Sortable Identifier) for primary keys
- **Devise Authentication** - Pre-configured User and Admin models
- **Avo Admin Panel** - Beautiful admin interface at `/avo`
- **Tailwind CSS v4** - Modern utility-first CSS framework
- **Solid Adapters** - Rails 8's new adapters for Cache, Queue, and Cable
- **Development Tools** - Rubocop, Brakeman, and Debug gems pre-configured
- **GitHub Actions** - Optional CI/CD setup
- **Cursor AI Rules** - Optional configuration for Cursor AI editor

## Usage

### Option 1: Using the template directly from GitHub

```bash
rails new myapp -m https://raw.githubusercontent.com/yourusername/yourrepo/main/template.rb
```

### Option 2: Using the template locally

```bash
rails new myapp -m /path/to/template.rb
```

### Option 3: Using with Rails edge

```bash
RAILS_EDGE=true rails new myapp -m template.rb
```

## What Gets Created

1. **Database Configuration**
   - SQLite with ULID extension enabled
   - Separate databases for cache, queue, and cable in production
   - All databases stored in the `storage/` directory

2. **Models**
   - `User` model with Devise authentication and ULID primary key
   - `Admin` model with Devise authentication and ULID primary key

3. **Routes**
   - Root route pointing to `home#index`
   - Devise routes for users and admins
   - Avo admin panel mounted at `/avo`

4. **Development Setup**
   - `Procfile.dev` for running the development server with `bin/dev`
   - Tailwind CSS watcher configured

5. **Code Quality**
   - `.rubocop.yml` configured with Rails Omakase style guide
   - Optional GitHub Actions workflow for CI

## Post-Installation Steps

After creating your new Rails application:

1. **Start the development server:**
   ```bash
   cd myapp
   bin/dev
   ```

2. **Create your first admin user:**
   ```bash
   rails console
   Admin.create!(email: "admin@example.com", password: "password")
   ```

3. **Access the admin panel:**
   Visit `http://localhost:3000/avo` and login with your admin credentials

4. **Customize Avo resources:**
   Generate Avo resources for your models:
   ```bash
   rails generate avo:resource User
   rails generate avo:resource Admin
   ```

## ULID Primary Keys

This template configures all models to use ULID as primary keys instead of integers. ULIDs provide:

- Lexicographically sortable identifiers
- Cryptographically secure randomness
- Better performance for distributed systems
- Natural ordering by creation time

When creating new models, they will automatically use ULID:

```bash
rails generate model Product name:string price:decimal
```

The migration will automatically use:
```ruby
create_table :products, id: false do |t|
  t.primary_key :id, :string, default: -> { "ULID()" }
  # ... other columns
end
```

## Customization

You can customize the template by modifying `template.rb`:

- Add or remove gems
- Change the default authentication setup
- Modify the home page template
- Add additional initializers or configurations

## Requirements

- Ruby 3.3 or higher
- Rails 8.0 or higher
- SQLite 3.8.0 or higher

## License

This template is available as open source under the terms of the MIT License. 