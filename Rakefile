# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[test rubocop]

# Parse --stage=VALUE from command line
def parse_stage
  ARGV.each do |arg|
    return Regexp.last_match(1) if arg =~ /\A--stage=(.+)\z/
  end
  nil
end

# Deployment tasks
namespace :deploy do
  # Stage configuration helper
  def stage_config
    stage = parse_stage || ENV.fetch("STAGE", "dev")
    case stage
    when "prod"
      { dir: "/var/www/grca", port: 4567, service: "grca", instance: "prod", stage: stage }
    when "test"
      { dir: "/var/www/grca-test", port: 4568, service: "grca-test", instance: "test", stage: stage }
    when "dev"
      { dir: "/var/www/grca-dev", port: 4569, service: "grca-dev", instance: "dev", stage: stage }
    else
      abort "Error: Unknown stage '#{stage}'. Use: --stage=prod, --stage=test, or --stage=dev"
    end
  end

  desc "Install all gem dependencies"
  task :install_gems do
    puts "Installing gems system-wide (no vendor/bundle)..."
    # Use --system to install gems system-wide instead of in vendor/bundle
    # This is cleaner for RVM-managed environments
    sh "bundle config set path.system true"
    sh "bundle install"
    puts "Gems installed successfully!"
    puts "\nNote: Gems are installed system-wide in your RVM environment."
    puts "No vendor/bundle directory created."
  end

  desc "Deploy nginx configuration to /etc/nginx/sites-available"
  task :nginx_config do
    require "fileutils"

    config = stage_config
    nginx_config = File.join(__dir__, "nginx.example.conf")
    destination = "/etc/nginx/sites-available/#{config[:service]}"

    abort "Error: nginx.example.conf not found in project root" unless File.exist?(nginx_config)

    puts "Deploying nginx configuration to #{destination}..."

    # Check if running as root or with sudo
    unless Process.uid.zero?
      puts "\n" + "=" * 60
      puts "ERROR: This task requires sudo privileges"
      puts "=" * 60
      puts "\nPlease run with sudo:"
      puts "  sudo rake deploy:nginx_config"
      puts "\nOr if using RVM:"
      puts "  rvmsudo rake deploy:nginx_config"
      puts "=" * 60
      abort "Error: This task must be run with sudo privileges"
    end

    FileUtils.cp(nginx_config, destination)
    FileUtils.chmod 0o644, destination

    puts "Nginx configuration deployed successfully!"
    puts "\nNext steps:"
    puts "1. Edit #{destination} to match your domain and paths"
    puts "2. Enable the site: ln -s #{destination} /etc/nginx/sites-enabled/"
    puts "3. Test nginx config: nginx -t"
    puts "4. Reload nginx: systemctl reload nginx"
  end

  desc "Create systemd service file for GRCA app (use --stage=prod|test|dev)"
  task :systemd_service do
    require "fileutils"

    config = stage_config

    service_content = <<~SERVICE
      [Unit]
      Description=GRCA Web Application - #{config[:stage]} (Thin Server)
      After=network.target
      #{ }
      [Service]
      Type=simple
      User=steffenr
      Group=rvm
      WorkingDirectory=#{config[:dir]}
      Environment="BUNDLE_GEMFILE=#{config[:dir]}/Gemfile"
      Environment="RACK_ENV=production"
      Environment="GRCA_INSTANCE=#{config[:instance]}"
      Environment="GRCA_PORT=#{config[:port]}"
      Environment="GEM_HOME=/usr/local/rvm/gems/ruby-4.0.1"
      Environment="GEM_PATH=/usr/local/rvm/gems/ruby-4.0.1:/usr/local/rvm/gems/ruby-4.0.1@global"
      # Source RVM and run thin directly
      ExecStart=/bin/bash -c 'source /usr/local/rvm/scripts/rvm && cd #{config[:dir]} && bundle exec thin -e production -p #{config[:port]} start'
      Restart=always
      RestartSec=5
      StandardOutput=journal
      StandardError=journal
      SyslogIdentifier=#{config[:service]}
      #{ }
      [Install]
      WantedBy=multi-user.target
    SERVICE

    destination = "/etc/systemd/system/#{config[:service]}.service"

    puts "Creating systemd service file at #{destination}..."

    # Check if running as root or with sudo
    unless Process.uid.zero?
      puts "\n" + "=" * 60
      puts "ERROR: This task requires sudo privileges"
      puts "=" * 60
      puts "\nPlease run with sudo:"
      puts "  sudo rake deploy:systemd_service"
      puts "\nOr if using RVM:"
      puts "  rvmsudo rake deploy:systemd_service"
      puts "=" * 60
      abort "Error: This task must be run with sudo privileges"
    end

    File.write(destination, service_content)
    FileUtils.chmod 0o644, destination

    puts "Systemd service file created successfully!"
    puts "\nNext steps:"
    puts "1. Reload systemd daemon: systemctl daemon-reload"
    puts "2. Enable service: systemctl enable grca"
    puts "3. Start service: systemctl start grca"
    puts "4. Check status: systemctl status grca"

    puts "\nNote: Service configured to use RVM wrapper for Ruby environment." if rvm_installed
  end

  desc "Copy web application files (use --stage=prod|test|dev)"
  task :copy_files do
    require "fileutils"

    config = stage_config
    destination = config[:dir]

    puts "Copying web application files to #{destination}..."

    # Check if running as root or with sudo
    unless Process.uid.zero?
      puts "\n" + "=" * 60
      puts "ERROR: This task requires sudo privileges"
      puts "=" * 60
      puts "\nPlease run with sudo:"
      puts "  sudo rake deploy:copy_files"
      puts "\nOr if using RVM:"
      puts "  rvmsudo rake deploy:copy_files"
      puts "=" * 60
      abort "Error: This task must be run with sudo privileges"
    end

    # Create destination directory
    FileUtils.mkdir_p(destination)

    # Create a production Gemfile (no gemspec dependency)
    puts "Creating production Gemfile..."
    production_gemfile = <<~GEMFILE
      # frozen_string_literal: true

      source "https://rubygems.org"

      # Production dependencies only - no development/test gems
      gem "sinatra", "~> 3.0"
      gem "thin", "~> 1.8"
      gem "webrick", "~> 1.8"
      gem "redis", "~> 5.0"
      gem "ostruct", "~> 0.6"
      gem "logger"
      gem "irb"
    GEMFILE

    File.write(File.join(destination, "Gemfile"), production_gemfile)

    # Files and directories to copy for production deployment
    # Note: Rakefile and gemspec are NOT needed - only runtime files
    files_to_copy = [
      "lib",       # Application code
      "views",     # ERB templates
      "bin/grca_web",  # Web server launcher
      "config.ru"      # Rack configuration file
    ]

    # Copy each file/directory
    files_to_copy.each do |file|
      source = File.join(__dir__, file)
      dest = File.join(destination, file)

      next unless File.exist?(source)

      if File.directory?(source)
        puts "  Copying directory: #{file}"
        FileUtils.rm_rf(dest)
        FileUtils.cp_r(source, dest)
      else
        puts "  Copying file: #{file}"
        # Ensure parent directory exists
        FileUtils.mkdir_p(File.dirname(dest))
        FileUtils.cp(source, dest)
      end
    end

    # Create log directory for Thin logs
    log_dir = "/var/log/#{config[:service]}"
    puts "Creating log directory at #{log_dir}..."
    FileUtils.mkdir_p(log_dir)
    FileUtils.chown_R("steffenr", "rvm", log_dir)

    # Set proper ownership
    puts "Setting ownership to steffenr:rvm..."
    FileUtils.chown_R("steffenr", "rvm", destination)

    # Make grca_web executable
    FileUtils.chmod(0o755, File.join(destination, "bin", "grca_web"))

    puts "\nWeb application files copied to #{destination} successfully!"
    puts "Stage: #{config[:stage]} | Port: #{config[:port]} | Service: #{config[:service]}"
    puts "\nNext steps:"
    puts "1. Run: cd #{destination} && rvmsudo rake deploy:install_gems"
    puts "2. Run: rvmsudo rake deploy:systemd_service --stage=#{config[:stage]}"
    puts "3. sudo systemctl daemon-reload"
    puts "4. sudo systemctl enable #{config[:service]}"
    puts "5. sudo systemctl start #{config[:service]}"
  end

  desc "Complete deployment guide (use --stage=prod|test|dev)"
  task :all do
    config = stage_config
    puts "\n" + "=" * 60
    puts "DEPLOYMENT GUIDE - #{config[:stage].upcase} Stage"
    puts "=" * 60
    puts "\nTarget: #{config[:dir]} | Port: #{config[:port]} | Service: #{config[:service]}"
    puts "\n" + "=" * 60
    puts "Deployment Steps:"
    puts "=" * 60
    puts "\nStep 1: Copy files to deployment location"
    puts "  rvmsudo rake deploy:copy_files --stage=#{config[:stage]}"
    puts "\nStep 2: Install gems (run from #{config[:dir]})"
    puts "  cd #{config[:dir]} && rvmsudo rake deploy:install_gems"
    puts "\nStep 3: Create systemd service"
    puts "  rvmsudo rake deploy:systemd_service --stage=#{config[:stage]}"
    puts "\nStep 4: Activate"
    puts "  sudo systemctl daemon-reload"
    puts "  sudo systemctl enable #{config[:service]}"
    puts "  sudo systemctl start #{config[:service]}"
    puts "  sudo systemctl status #{config[:service]}"
    puts "\n" + "=" * 60
    puts "All stages:"
    puts "  rvmsudo rake deploy:all --stage=prod"
    puts "  rvmsudo rake deploy:all --stage=test"
    puts "  rvmsudo rake deploy:all --stage=dev"
    puts "=" * 60
  end
end
