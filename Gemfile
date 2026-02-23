# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in grca.gemspec
gemspec

gem "irb"
gem "rake", "~> 13.0"

gem "minitest", "~> 5.16"

gem "rubocop", "~> 1.21"

# Web servers
gem "thin", "~> 1.8"
gem "webrick", "~> 1.8" # For development fallback

# Redis for production caching
gem "redis", "~> 5.0"

group :development do
  # Auto-reload on file changes
  gem "rerun"
end
