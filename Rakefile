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

  desc "Create systemd service file for GRCA app"
  task :systemd_service do
    require "fileutils"

    # Detect RVM installation
    rvm_installed = system("command -v rvm >/dev/null 2>&1")
    rvm_wrapper_path = "/usr/local/rvm/gems/$(ruby -v | cut -d' ' -f1)/bin/wrapper"

    service_content = if rvm_installed
                        # Use RVM wrapper for systemd
                        <<~SERVICE
                          [Unit]
                          Description=GRCA Web Application (Thin Server)
                          After=network.target
                          #{"  "}
                          [Service]
                          Type=simple
                          User=www-data
                          Group=www-data
                          WorkingDirectory=/var/www/grca
                          Environment="BUNDLE_GEMFILE=/var/www/grca/Gemfile"
                          Environment="RACK_ENV=production"
                          # Use RVM wrapper script to run Thin with correct Ruby version
                          ExecStart=#{rvm_wrapper_path} thin -e production -p 4567 -P /tmp/grca.pid -l /tmp/grca.log start
                          Restart=always
                          RestartSec=5
                          StandardOutput=journal
                          StandardError=journal
                          SyslogIdentifier=grca
                          #{"  "}
                          [Install]
                          WantedBy=multi-user.target
                        SERVICE
                      else
                        # Fallback to bundle exec
                        <<~SERVICE
                          [Unit]
                          Description=GRCA Web Application (Thin Server)
                          After=network.target
                          #{"  "}
                          [Service]
                          Type=simple
                          User=www-data
                          Group=www-data
                          WorkingDirectory=/var/www/grca
                          Environment="BUNDLE_GEMFILE=/var/www/grca/Gemfile"
                          Environment="RACK_ENV=production"
                          # Use Thin for fast, lightweight web serving
                          ExecStart=/usr/bin/bundle exec thin -e production -p 4567 -P /tmp/grca.pid -l /tmp/grca.log start
                          Restart=always
                          RestartSec=5
                          StandardOutput=journal
                          StandardError=journal
                          SyslogIdentifier=grca
                          #{"  "}
                          [Install]
                          WantedBy=multi-user.target
                        SERVICE
                      end

    destination = "/etc/systemd/system/grca.service"

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

  desc "Copy web application files to /var/www/grca"
  task :copy_files do
    require "fileutils"

    destination = "/var/www/grca"

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

    # Files and directories to copy
    files_to_copy = [
      "lib",
      "views",
      "Gemfile",
      "Gemfile.lock",
      "bin/grca_web",
      "config.ru",
      ".ruby-version" # Copy RVM version file if it exists
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
    puts "1. Run: rvmsudo rake deploy:install_gems (in /var/www/grca)"
    puts "   OR: sudo -E rake deploy:install_gems (preserves your environment)"
    puts "2. Run: rvmsudo rake deploy:systemd_service"
    puts "3. Run: rvmsudo rake deploy:nginx_config"
    puts "4. Configure nginx and enable the site"
    puts "\nNote: Use 'rvmsudo' instead of 'sudo' to preserve RVM environment,"
    puts "      or use 'sudo -E' to preserve your environment variables."
  end

  desc "Complete deployment - runs all deployment tasks"
  task :all do
    puts "\n" + "=" * 60
    puts "DEPLOYMENT GUIDE - Complete Deployment Steps"
    puts "=" * 60
    puts "\nThis task requires sudo privileges for system-level operations."
    puts "\nRVM USERS: Use 'rvmsudo' or 'sudo -E' to preserve your Ruby environment:"
    puts "  rvmsudo rake deploy:copy_files"
    puts "  cd /var/www/grca && rvmsudo rake deploy:install_gems"
    puts "\nSTANDARD SUDO (may not work with RVM):"
    puts "  sudo rake deploy:copy_files"
    puts "  cd /var/www/grca && sudo rake deploy:install_gems"
    puts "\n" + "=" * 60
    puts "Deployment Steps:"
    puts "=" * 60
    puts "\nStep 1: Copy files to deployment location"
    puts "  rvmsudo rake deploy:copy_files"
    puts "\nStep 2: Install gems (run from /var/www/grca)"
    puts "  cd /var/www/grca && rvmsudo rake deploy:install_gems"
    puts "\nStep 3: Create systemd service"
    puts "  rvmsudo rake deploy:systemd_service"
    puts "\nStep 4: Deploy nginx configuration"
    puts "  rvmsudo rake deploy:nginx_config"
    puts "\n" + "=" * 60
    puts "After deployment:"
    puts "=" * 60
    puts "1. Edit /etc/nginx/sites-available/grca to match your domain"
    puts "2. Enable nginx site: ln -s /etc/nginx/sites-available/grca /etc/nginx/sites-enabled/"
    puts "3. Test nginx: nginx -t"
    puts "4. Reload systemd: systemctl daemon-reload"
    puts "5. Enable service: systemctl enable grca"
    puts "6. Start service: systemctl start grca"
    puts "7. Reload nginx: systemctl reload nginx"
    puts "8. Check status: systemctl status grca"
    puts "=" * 60
    puts "\nALTERNATIVE: Manual deployment without RVM"
    puts "-" * 60
    puts "If you prefer not to use RVM for the systemd service:"
    puts "1. Install Ruby system-wide: apt install ruby-full"
    puts "2. Install gems: sudo gem install thin bundler"
    puts "3. The systemd service will use bundle exec automatically"
    puts "=" * 60
  end
end
