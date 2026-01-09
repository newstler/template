# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create first admin
admin_email = ENV["FIRST_ADMIN_EMAIL"] || "admin@example.com"
admin = Admin.find_or_create_by!(email: admin_email)
puts "✓ Admin created: #{admin.email}"
