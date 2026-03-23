# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[test rubocop]

# Deployment tasks
namespace :deploy do
  STAGES = {
    "prod" => { dir: "/var/www/grca", port: 4567, service: "grca", instance: "prod", stage: "prod" },
    "test" => { dir: "/var/www/grca-test", port: 4568, service: "grca-test", instance: "test", stage: "test" },
    "dev" => { dir: "/var/www/grca-dev", port: 4569, service: "grca-dev", instance: "dev", stage: "dev" }
  }.freeze

  # Require sudo helper
  def require_sudo!(task_name)
    return if Process.uid.zero?

    puts "\n" + "=" * 60
    puts "ERROR: This task requires sudo privileges"
    puts "=" * 60
    puts "\nPlease run with:"
    puts "  rvmsudo rake #{task_name}"
    puts "=" * 60
    abort
  end

  # Copy files for a given stage config
  def deploy_files(config)
    require "fileutils"

    destination = config[:dir]
    puts "Copying web application files to #{destination}..."

    require_sudo!("deploy:#{config[:stage]}")

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
    files_to_copy = ["lib", "views", "bin/grca_web", "config.ru"]

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
        FileUtils.mkdir_p(File.dirname(dest))
        FileUtils.cp(source, dest)
      end
    end

    # Create log directory
    log_dir = "/var/log/#{config[:service]}"
    puts "Creating log directory at #{log_dir}..."
    FileUtils.mkdir_p(log_dir)
    FileUtils.chown_R("steffenr", "rvm", log_dir)

    # Set proper ownership
    puts "Setting ownership to steffenr:rvm..."
    FileUtils.chown_R("steffenr", "rvm", destination)
    FileUtils.chmod(0o755, File.join(destination, "bin", "grca_web"))

    puts "\nDeployed to #{destination} successfully!"
    puts "Stage: #{config[:stage]} | Port: #{config[:port]} | Service: #{config[:service]}"

    # Install gems in the deployment directory
    puts "\nInstalling gems in #{destination}..."
    Dir.chdir(destination) do
      sh "bundle config set --local path.system true"
      sh "bundle install"
    end
    puts "Gems installed."

    # Reload systemd, enable and restart the service
    puts "\nActivating service #{config[:service]}..."
    sh "systemctl daemon-reload"
    sh "systemctl enable #{config[:service]}"
    sh "systemctl restart #{config[:service]}"
    puts "Service #{config[:service]} is running."
  end

  # Generate per-stage deploy tasks: deploy:dev, deploy:test, deploy:prod
  STAGES.each do |name, config|
    desc "Deploy to #{name}"
    task name.to_sym do
      deploy_files(config)
    end
  end

  desc "Deploy to all stages"
  task all: %i[dev test prod]

  desc "Deploy nginx configuration to /etc/nginx/sites-available"
  task :nginx_config do
    require "fileutils"

    nginx_config = File.join(__dir__, "nginx.example.conf")

    abort "Error: nginx.example.conf not found in project root" unless File.exist?(nginx_config)

    require_sudo!("deploy:nginx_config")

    puts "Deploying nginx configuration..."
    FileUtils.cp(nginx_config, "/etc/nginx/sites-available/grca")
    FileUtils.chmod 0o644, "/etc/nginx/sites-available/grca"

    puts "Nginx configuration deployed successfully!"
    puts "\nNext steps:"
    puts "1. Enable the site: ln -s /etc/nginx/sites-available/grca /etc/nginx/sites-enabled/"
    puts "2. Test nginx config: nginx -t"
    puts "3. Reload nginx: systemctl reload nginx"
  end

  desc "Create systemd service file for a stage"
  STAGES.each do |name, config|
    task :"systemd_#{name}" do
      require "fileutils"

      require_sudo!("deploy:systemd_#{name}")

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
      File.write(destination, service_content)
      FileUtils.chmod 0o644, destination

      puts "Systemd service file created for #{name}!"
      puts "  sudo systemctl daemon-reload"
      puts "  sudo systemctl enable #{config[:service]}"
      puts "  sudo systemctl restart #{config[:service]}"
    end
  end

  desc "Show deployment guide"
  task :help do
    puts "\n" + "=" * 60
    puts "GRCA DEPLOYMENT"
    puts "=" * 60
    puts "\nDeploy a stage:"
    puts "  rvmsudo rake deploy:dev"
    puts "  rvmsudo rake deploy:test"
    puts "  rvmsudo rake deploy:prod"
    puts "\nDeploy all stages:"
    puts "  rvmsudo rake deploy:all"
    puts "\nSystemd services:"
    puts "  rvmsudo rake deploy:systemd_dev"
    puts "  rvmsudo rake deploy:systemd_test"
    puts "  rvmsudo rake deploy:systemd_prod"
    puts "\nOther:"
    puts "  rvmsudo rake deploy:nginx_config  # Deploy nginx config"
    puts "=" * 60
  end
end
