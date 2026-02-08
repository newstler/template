namespace :production do
  namespace :pull do
    desc "Pull production database to development"
    task db: :environment do
      config = ProductionPullConfig.new
      db_puller = ProductionDbPuller.new(config)
      db_puller.call
    end

    desc "Pull production ActiveStorage files to development"
    task files: :environment do
      config = ProductionPullConfig.new
      files_puller = ProductionFilesPuller.new(config)
      files_puller.call
    end
  end

  desc "Pull production database and files to development"
  task pull: :environment do
    Rake::Task["production:pull:db"].invoke
    Rake::Task["production:pull:files"].invoke
  end
end

class ProductionPullConfig
  attr_reader :server_ip, :volume_name, :ssh_user, :dev_db_path, :storage_root

  def initialize
    deploy = YAML.safe_load_file(Rails.root.join("config/deploy.yml"), permitted_classes: [ Symbol ])
    db_config = YAML.safe_load(ERB.new(File.read(Rails.root.join("config/database.yml"))).result, permitted_classes: [ Symbol ])

    @server_ip = extract_server_ip(deploy)
    @volume_name = extract_volume_name(deploy)
    @ssh_user = ENV.fetch("DEPLOY_SSH_USER", "root")
    @dev_db_path = Rails.root.join(db_config.dig("development", "database"))
    @storage_root = Rails.root.join("storage")
  end

  def remote_volume_path
    "/var/lib/docker/volumes/#{volume_name}/_data"
  end

  def remote_db_path
    "#{remote_volume_path}/production.sqlite3"
  end

  def ssh_target
    "#{ssh_user}@#{server_ip}"
  end

  private

  def extract_server_ip(deploy)
    servers = deploy.fetch("servers")
    hosts = servers.is_a?(Array) ? servers : servers.fetch("web")
    hosts.first
  end

  def extract_volume_name(deploy)
    volume_entry = deploy.fetch("volumes").first
    volume_entry.split(":").first
  end
end

class ProductionDbPuller
  def initialize(config)
    @config = config
  end

  def call
    confirm_overwrite!
    download_production_db
    backup_dev_db
    restore_production_to_dev
    run_migrations
    print_summary
  end

  private

  def confirm_overwrite!
    return if ENV["CONFIRM"] == "yes"

    print "\n⚠️  This will replace your development database with production data. Continue? [y/N] "
    answer = $stdin.gets.chomp
    abort "Aborted." unless answer.downcase == "y"
  end

  def download_production_db
    puts "\n→ Downloading production database..."
    @tmp_file = Rails.root.join("tmp/production.sqlite3")
    FileUtils.mkdir_p(Rails.root.join("tmp"))

    sh "scp #{@config.ssh_target}:#{@config.remote_db_path} #{@tmp_file}"
    puts "  Downloaded to #{@tmp_file}"
  end

  def backup_dev_db
    return unless File.exist?(@config.dev_db_path)

    backup_path = "#{@config.dev_db_path}.backup"
    puts "\n→ Backing up development database to #{backup_path}"
    FileUtils.cp(@config.dev_db_path, backup_path)
  end

  def restore_production_to_dev
    puts "\n→ Restoring production database to development..."
    FileUtils.rm_f(@config.dev_db_path)

    sh "sqlite3 #{@tmp_file} .dump | sqlite3 #{@config.dev_db_path}"
    FileUtils.rm_f(@tmp_file)
    puts "  Restored successfully"
  end

  def run_migrations
    puts "\n→ Running pending migrations..."
    Rake::Task["db:migrate"].invoke
  end

  def print_summary
    puts "\n✓ Development database replaced with production data"
    puts "\n  Record counts:"
    ActiveRecord::Base.connection.tables.sort.each do |table|
      next if table.start_with?("ar_internal_metadata", "schema_migrations", "solid_")

      count = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{table}")
      puts "    #{table}: #{count}"
    end
  end

  def sh(command)
    system(command) || abort("Command failed: #{command}")
  end
end

class ProductionFilesPuller
  def initialize(config)
    @config = config
  end

  def call
    puts "\n→ Syncing production storage files..."
    sh "rsync -az --exclude='*.sqlite3*' --exclude='.keep' " \
       "#{@config.ssh_target}:#{@config.remote_volume_path}/ #{@config.storage_root}/"
    puts "\n✓ Storage files synced to #{@config.storage_root}"
  end

  private

  def sh(command)
    system(command) || abort("Command failed: #{command}")
  end
end
