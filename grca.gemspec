# frozen_string_literal: true

require_relative "lib/grca/version"

Gem::Specification.new do |spec|
  spec.name = "grca"
  spec.version = Grca::VERSION
  spec.authors = ["Steffen Roller"]
  spec.email = ["[YOUR-EMAIL]@example.com"]

  spec.summary = "Grand River Conservation Authority - Realtime sensor data access"
  spec.description = "GRCA provides easy access to (near-)realtime sensor data from the Grand River Conservation Authority. This application presents a web interface to view current conditions from stations along the rivers in the Grand River watershed."
  spec.homepage = "https://github.com/sroller/grca"
  spec.required_ruby_version = ">= 3.2.0"

  # Private application - not for publication on RubyGems
  spec.metadata["private"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "ostruct", "~> 0.6"
  spec.add_dependency "sinatra", "~> 3.0"
  spec.add_dependency "webrick", "~> 1.8"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
