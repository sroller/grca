# frozen_string_literal: true

module Grca
  # Helper methods for view formatting
  module Helpers
    # Format a numeric value with one decimal place
    def format_value(value)
      return "-" if value.nil?

      Float(value).round(1)
    rescue ArgumentError, TypeError
      value
    end

    # Format a percentage as an integer
    def format_percent(value)
      return nil if value.nil?

      Integer(value.round)
    rescue ArgumentError, TypeError
      nil
    end

    # Format unit string with proper Unicode characters
    def format_unit(unit)
      return "" if unit.nil? || unit.empty?

      # Use superscript ³ (U+00B3) for cubic meter (case-insensitive)
      unit.gsub(%r{m3/s}i, "m³/s").gsub(/m3/i, "m³")
    end

    # Generate a URL that respects the SCRIPT_NAME base path
    # This allows the app to work under a subdirectory in nginx
    def url_for(path)
      # Get the base path from SCRIPT_NAME (set by nginx)
      # Note: nginx passes this as HTTP_SCRIPT_NAME which Rack converts
      script_name = request.env["HTTP_SCRIPT_NAME"] || request.env["SCRIPT_NAME"] || ""
      # Log for debugging
      logger.info "url_for called: script_name='#{script_name}', path='#{path}'"
      # Ensure path starts with /
      path = "/#{path}" unless path.start_with?("/")
      result = "#{script_name}#{path}"
      logger.info "url_for result: '#{result}'"
      result
    end

    # Check if current path matches the given path
    def current_path?(path)
      request.path == url_for(path)
    end
  end
end
