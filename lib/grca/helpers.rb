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
  end
end
