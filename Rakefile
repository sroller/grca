# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[test rubocop]

# Deployment tasks
namespace :deploy do
  desc "Install all gem dependencies"
  task :install_gems do
    puts "Installing gems..."
    sh "bundle install --deployment --without development test"
    puts "Gems installed successfully!"
  end

  desc "Deploy nginx configuration to /etc/nginx/sites-available"
  task :nginx_config do
    require "fileutils"

    nginx_config = File.join(__dir__, "nginx.example.conf")
    destination = "/etc/nginx/sites-available/grca"

    abort "Error: nginx.example.conf not found in project root" unless File.exist?(nginx_config)

    puts "Deploying nginx configuration to #{destination}..."

    # Check if running as root or with sudo
    abort "Error: This task must be run with sudo privileges" unless Process.uid.zero?

    FileUtils.cp(nginx_config, destination)
    FileUtils.chmod 0o644, destination

    puts "Nginx configuration deployed successfully!"
    puts "\nNext steps:"
    puts "1. Edit #{destination} to match your domain and paths"
    puts "2. Enable the site: ln -s #{destination} /etc/nginx/sites-enabled/"
    puts "3. Test nginx config: nginx -t"
    puts "4. Reload nginx: systemctl reload nginx"
  end

  desc "Create systemd service file for GRCA app"
  task :systemd_service do
    require "fileutils"

    service_content = <<~SERVICE
      [Unit]
      Description=GRCA Web Application (Puma Server)
      After=network.target

      [Service]
      Type=simple
      User=www-data
      Group=www-data
      WorkingDirectory=/var/www/grca
      Environment="BUNDLE_GEMFILE=/var/www/grca/Gemfile"
      Environment="RACK_ENV=production"
      # Use Puma for better performance and concurrency
      ExecStart=/usr/bin/bundle exec puma -C config/puma.rb
      Restart=always
      RestartSec=5
      StandardOutput=journal
      StandardError=journal
      SyslogIdentifier=grca

      [Install]
      WantedBy=multi-user.target
    SERVICE

    destination = "/etc/systemd/system/grca.service"

    puts "Creating systemd service file at #{destination}..."

    # Check if running as root or with sudo
    abort "Error: This task must be run with sudo privileges" unless Process.uid.zero?

    File.write(destination, service_content)
    FileUtils.chmod 0o644, destination

    puts "Systemd service file created successfully!"
    puts "\nNext steps:"
    puts "1. Reload systemd daemon: systemctl daemon-reload"
    puts "2. Enable service: systemctl enable grca"
    puts "3. Start service: systemctl start grca"
    puts "4. Check status: systemctl status grca"
  end

  desc "Copy web application files to /var/www/grca"
  task :copy_files do
    require "fileutils"

    destination = "/var/www/grca"

    puts "Copying web application files to #{destination}..."

    # Check if running as root or with sudo
    abort "Error: This task must be run with sudo privileges" unless Process.uid.zero?

    # Create destination directory
    FileUtils.mkdir_p(destination)

    # Files and directories to copy
    files_to_copy = [
      "lib",
      "views",
      "config", # Puma configuration
      "Gemfile",
      "Gemfile.lock",
      "bin/grca_web",
      "config.ru"
    ]

    # Copy each file/directory
    files_to_copy.each do |file|
      source = File.join(__dir__, file)
      dest = File.join(destination, file)

      if File.directory?(source)
        puts "  Copying directory: #{file}"
        FileUtils.rm_rf(dest)
        FileUtils.cp_r(source, dest)
      else
        puts "  Copying file: #{file}"
        FileUtils.cp(source, dest)
      end
    end

    # Create log directory for Puma logs
    puts "Creating log directory..."
    FileUtils.mkdir_p("/var/log/grca")
    FileUtils.chown_R("www-data", "www-data", "/var/log/grca")

    # Set proper ownership
    puts "Setting ownership to www-data..."
    FileUtils.chown_R("www-data", "www-data", destination)

    # Make grca_web executable
    FileUtils.chmod(0o755, File.join(destination, "bin", "grca_web"))

    puts "\nWeb application files copied successfully!"
    puts "\nNext steps:"
    puts "1. Run: rake deploy:install_gems"
    puts "2. Run: rake deploy:systemd_service"
    puts "3. Run: rake deploy:nginx_config"
    puts "4. Configure nginx and enable the site"
  end

  desc "Complete deployment - runs all deployment tasks"
  task all: %i[install_gems copy_files systemd_service nginx_config] do
    puts "\n" + "=" * 60
    puts "Deployment complete!"
    puts "=" * 60
    puts "\nFinal steps:"
    puts "1. Edit /etc/nginx/sites-available/grca to match your domain"
    puts "2. Enable nginx site: ln -s /etc/nginx/sites-available/grca /etc/nginx/sites-enabled/"
    puts "3. Test nginx: nginx -t"
    puts "4. Reload systemd: systemctl daemon-reload"
    puts "5. Enable service: systemctl enable grca"
    puts "6. Start service: systemctl start grca"
    puts "7. Reload nginx: systemctl reload nginx"
    puts "8. Check status: systemctl status grca"
    puts "=" * 60
  end
end
