# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require_relative "cache"

module Grca
  # Service for identifying water bodies from station data and OSM
  class OsmService
    OVERPASS_ENDPOINTS = [
      "https://overpass-api.de/api/interpreter",
      "https://overpass.kumi.systems/api/interpreter"
    ].freeze
    RIVERS_OF_INTEREST = ["Grand River", "Speed River", "Nith River", "Conestogo River"].freeze
    SEARCH_RADIUS = 1000 # meters

    # River name patterns to extract from site_name
    RIVER_PATTERNS = {
      "Grand River" => /\bgrand\s*(river)?\b/i,
      "Speed River" => /\bspeed\s*(river)?\b/i,
      "Nith River" => /\bnith\s*(river)?\b/i,
      "Conestogo River" => /\bconestogo\s*(river)?\b/i,
      "Eramosa River" => /\beramosa\s*(river)?\b/i,
      "Laurel Creek" => /\blaurel\s*(creek)?\b/i,
      "Canagagigue Creek" => /\bcanagagigue\s*(creek)?\b/i,
      "Mill Creek" => /\bmill\s*(creek)?\b/i,
      "Fairchild Creek" => /\bfairchild\s*(creek)?\b/i,
      "Whitemans Creek" => /\bwhitemans?\s*(creek)?\b/i,
      "McKenzie Creek" => /\bmckenzie\s*(creek)?\b/i,
      "Horner Creek" => /\bhorner\s*(creek)?\b/i,
      "Clair Creek" => /\bclair\s*(creek)?\b/i,
      "Blair Creek" => /\bblair\s*(creek)?\b/i,
      "Black Creek" => /\bblack\s*(creek)?\b/i,
      "Alder Creek" => /\balder\s*(creek)?\b/i,
      "Moorefield Creek" => /\bmoorefield\s*(creek)?\b/i
    }.freeze

    def initialize
      @http_options = { open_timeout: 10, read_timeout: 30 }
    end

    # Extract water body name from site_name (preferred) or station name
    def extract_water_body_from_name(site_name, station_name = nil)
      text = site_name || station_name || ""

      RIVER_PATTERNS.each do |river_name, pattern|
        return river_name if text.match?(pattern)
      end

      nil
    end

    # Get the water body name - first try site_name, then OSM lookup
    # OSM lookup is disabled by default due to Overpass API reliability issues
    def get_water_body(latitude, longitude, site_name = nil, station_name = nil, use_osm: false)
      # First try to extract from site_name (most reliable)
      water_body = extract_water_body_from_name(site_name, station_name)
      return water_body if water_body

      # OSM lookup is disabled by default - can be enabled with use_osm: true
      return nil unless use_osm

      # Fall back to OSM lookup if we have coordinates
      return nil if latitude.nil? || longitude.nil?

      lat = latitude.to_f
      lon = longitude.to_f
      return nil if lat.zero? && lon.zero?

      cache_key = "osm_water_body:#{lat.round(4)},#{lon.round(4)}"

      Cache.fetch(cache_key, ttl: 7 * 24 * 60 * 60) do # Cache for 7 days
        query_overpass_for_waterway(lat, lon)
      end
    rescue StandardError => e
      puts "OSM API Error: #{e.message}"
      nil
    end

    # Tag stations with their nearby water body
    def tag_stations_with_rivers(stations)
      stations.map do |station|
        water_body = get_water_body(station[:latitude], station[:longitude])
        station.merge(
          water_body: water_body,
          river_of_interest: river_of_interest?(water_body)
        )
      end
    end

    # Filter stations to only those near rivers of interest
    def filter_by_rivers_of_interest(stations)
      tag_stations_with_rivers(stations).select { |s| s[:river_of_interest] }
    end

    # Check if a water body is one of the rivers of interest
    def river_of_interest?(water_body)
      return false if water_body.nil?

      RIVERS_OF_INTEREST.any? do |river|
        river_key = river.downcase.split.first # "grand", "speed", "nith", "conestogo"
        water_body.downcase.include?(river_key)
      end
    end

    # Extract the main river name from a water body name
    def extract_river_name(water_body)
      return nil if water_body.nil?

      RIVERS_OF_INTEREST.each do |river|
        river_key = river.downcase.split.first
        return river if water_body.downcase.include?(river_key)
      end

      water_body # Return original if not a known river
    end

    private

    def query_overpass_for_waterway(lat, lon)
      query = build_overpass_query(lat, lon)

      # Try each endpoint until one works
      OVERPASS_ENDPOINTS.each do |endpoint|
        result = try_overpass_endpoint(endpoint, query)
        return result if result
      end

      nil
    rescue StandardError => e
      puts "Overpass query failed: #{e.message}"
      nil
    end

    def try_overpass_endpoint(endpoint, query)
      uri = URI(endpoint)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = @http_options[:open_timeout]
      http.read_timeout = @http_options[:read_timeout]

      request = Net::HTTP::Post.new(uri.path)
      request["Content-Type"] = "application/x-www-form-urlencoded"
      request["User-Agent"] = "GRCA-Water-Monitor/1.0"
      request.body = "data=#{URI.encode_www_form_component(query)}"

      response = http.request(request)

      return nil unless response.code == "200"
      return nil if response.body.include?("<?xml") # Error response

      parse_overpass_response(response.body)
    rescue StandardError
      nil
    end

    def build_overpass_query(lat, lon)
      # Query for any waterway (rivers, streams, etc.)
      <<~OVERPASS
        [out:json][timeout:25];
        (
          way["waterway"](around:#{SEARCH_RADIUS},#{lat},#{lon});
          relation["waterway"](around:#{SEARCH_RADIUS},#{lat},#{lon});
        );
        out tags;
      OVERPASS
    end

    def parse_overpass_response(body)
      data = JSON.parse(body)
      elements = data["elements"] || []

      # Prefer rivers over streams, and prioritize rivers of interest
      rivers = []
      streams = []

      elements.each do |element|
        name = element.dig("tags", "name")
        next if name.nil? || name.empty?

        waterway_type = element.dig("tags", "waterway")
        if waterway_type == "river"
          rivers << name
        else
          streams << name
        end
      end

      # Return first river of interest, or first river, or first stream
      (rivers + streams).each do |name|
        return name if river_of_interest?(name)
      end

      rivers.first || streams.first
    end
  end
end
