# frozen_string_literal: true

# Puma configuration file for GRCA app

# Environment
environment ENV.fetch("RACK_ENV", "production")

# Bind to all interfaces on port 4567
bind "tcp://0.0.0.0:4567"

# Thread configuration
# Min threads: 1, Max threads: 16
threads 1, 16

# Workers (set to 0 for single-mode, increase for multi-process)
# For small deployments, single-mode is sufficient
workers 0

# Pidfile (optional, systemd doesn't need it)
pidfile nil

# Logging - will be captured by systemd journal
# stdout_redirect can be used in production with proper directory setup
# stdout_redirect "/var/log/grca/puma.stdout.log", "/var/log/grca/puma.stderr.log", true

# Preload app (only useful with workers > 0)
preload_app! false

# Tag for process identification
tag "grca"
