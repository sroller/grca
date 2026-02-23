# frozen_string_literal: true

require "sinatra"
require "sinatra/base"
require "json"
require "net/http"
require "uri"
require_relative "summer_low_reference"

module Grca
  class App < Sinatra::Base
    # Configure the app
    set :server, "webrick"
    set :bind, "0.0.0.0"
    set :port, 4567
    set :public_folder, File.join(File.dirname(__FILE__), "..", "..", "public")
    set :views, File.join(File.dirname(__FILE__), "..", "..", "views")

    # GRCA API base URL
    def api_base_url
      "https://waterdata.grandriver.ca/KiWIS/KiWIS"
    end

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

      # Use superscript ³ (U+00B3) for cubic meter
      unit.gsub("m3/s", "m³/s").gsub("m3", "m³")
    end

    # Get list of stations from GRCA API
    def get_stations
      uri = URI("#{api_base_url}?service=kisters&type=queryServices&request=getStationList&datasource=0&format=json")
      response = Net::HTTP.get_response(uri)

      if response.code == "200"
        data = JSON.parse(response.body)
        # The API returns an array where first row is header, subsequent rows are station data
        # Skip the header row and extract station names
        data.drop(1).map { |row| row[0] }.sort

      else
        []
      end
    rescue StandardError => e
      puts "Error fetching stations: #{e.message}"
      []
    end

    # Get station details by station_no
    def get_station_by_no(station_no)
      uri = URI("#{api_base_url}?service=kisters&type=queryServices&request=getStationInfo&datasource=0&format=json&station_no=#{station_no}")
      response = Net::HTTP.get_response(uri)

      if response.code == "200"
        JSON.parse(response.body)
      else
        nil
      end
    rescue StandardError => e
      puts "Error fetching station info: #{e.message}"
      nil
    end

    # Get timeseries list for one or more stations (comma-separated station_no)
    def get_timeseries_list(station_no)
      # Request additional fields for human-readable names and units
      returnfields = "station_name,station_no,ts_id,ts_name,parametertype_id,parametertype_name,stationparameter_name,stationparameter_longname,ts_unitsymbol"
      uri = URI("#{api_base_url}?service=kisters&type=queryServices&request=getTimeseriesList&datasource=0&format=json&station_no=#{station_no}&returnfields=#{returnfields}")
      response = Net::HTTP.get_response(uri)

      if response.code == "200"
        data = JSON.parse(response.body)
        # Skip header row and map to meaningful keys
        # Fields: station_name, station_no, ts_id, ts_name, parametertype_id, parametertype_name,
        #         stationparameter_name, stationparameter_longname, ts_unitsymbol
        data.drop(1).map do |row|
          {
            station_name: row[0],
            station_no: row[1],
            ts_id: row[2],
            ts_name: row[3],
            param_type_id: row[4],
            param_type_name: row[5],
            param_name: row[6],
            param_longname: row[7],
            unit: row[8]
          }
        end
      else
        []
      end
    rescue StandardError => e
      puts "Error fetching timeseries list: #{e.message}"
      []
    end

    # Get latest value for a timeseries
    def get_timeseries_value(ts_id, timezone = nil)
      url = "#{api_base_url}?service=kisters&type=queryServices&request=getTimeseriesValues&datasource=0&format=json&ts_id=#{ts_id}"
      url += "&timezone=#{URI.encode_www_form_component(timezone)}" if timezone && !timezone.empty?
      uri = URI(url)
      response = Net::HTTP.get_response(uri)

      if response.code == "200"
        data = JSON.parse(response.body)
        # Response is an array with one element containing the data
        return nil unless data.is_a?(Array) && !data.empty?

        data_hash = data[0]

        if data_hash["data"] && !data_hash["data"].empty?
          {
            timestamp: data_hash["data"][0][0],
            value: data_hash["data"][0][1]
          }
        else
          nil
        end
      else
        nil
      end
    rescue StandardError => e
      puts "Error fetching timeseries value: #{e.message}"
      nil
    end

    # Get latest values for multiple timeseries (comma-separated ts_id)
    # Returns a hash keyed by ts_id
    def get_timeseries_values_batch(ts_ids, timezone = nil)
      return {} if ts_ids.nil? || ts_ids.empty?

      url = "#{api_base_url}?service=kisters&type=queryServices&request=getTimeseriesValues&datasource=0&format=json&ts_id=#{ts_ids}"
      url += "&timezone=#{URI.encode_www_form_component(timezone)}" if timezone && !timezone.empty?
      uri = URI(url)
      response = Net::HTTP.get_response(uri)

      if response.code == "200"
        data = JSON.parse(response.body)
        return {} unless data.is_a?(Array)

        # When requesting multiple ts_ids, the API returns an array of results
        # Each element contains ts_id and its data
        results = {}
        data.each do |ts_data|
          ts_id = ts_data["ts_id"]
          next unless ts_data["data"] && !ts_data["data"].empty?

          results[ts_id] = {
            timestamp: ts_data["data"][0][0],
            value: ts_data["data"][0][1]
          }
        end
        results
      else
        {}
      end
    rescue StandardError => e
      puts "Error fetching timeseries values batch: #{e.message}"
      {}
    end

    # Check if a timestamp is too old (more than 30 days)
    def stale_timestamp?(timestamp_str)
      return true if timestamp_str.nil?

      timestamp = begin
        Time.parse(timestamp_str)
      rescue StandardError
        nil
      end
      return true if timestamp.nil?

      timestamp < (Time.now.utc - 30 * 24 * 60 * 60)
    end

    # Check if a measurement value is valid for the given parameter type
    def valid_measurement_value?(param_type, value)
      return false if value.nil?

      param_type_lower = param_type.to_s.downcase
      val = value.to_f

      case param_type_lower
      when /air.*temp/, /^temperature$/
        # Air temperature should be between -60°C and 60°C
        val >= -60 && val <= 60
      when /water.*temp/
        # Water temperature should be between -5°C and 40°C
        val >= -5 && val <= 40
      when /stage/, /level/
        # Stage/level should be reasonable (not negative unless it's a datum offset)
        val >= -100 && val <= 1000
      when /flow/
        # Flow should be non-negative and reasonable
        val >= 0 && val <= 100_000
      when /precip/
        # Precipitation should be non-negative
        val >= 0 && val <= 500
      else
        # Default: accept any value
        true
      end
    end

    # Filter out invalid measurements
    def filter_valid_measurement(measurement)
      return nil if measurement.nil?

      # Check for stale timestamp
      return nil if stale_timestamp?(measurement[:time] || measurement[:timestamp])

      # Check for invalid values based on parameter type
      param = measurement[:parameter].to_s.downcase
      value = measurement[:value]

      return nil unless valid_measurement_value?(param, value)

      measurement
    end

    # Get timeseries values for a period (e.g., "P7D" for 7 days, "P24H" for 24 hours)
    def get_timeseries_values_for_period(ts_id, period, timezone = nil)
      url = "#{api_base_url}?service=kisters&type=queryServices&request=getTimeseriesValues&datasource=0&format=json&ts_id=#{ts_id}&period=#{period}"
      url += "&timezone=#{URI.encode_www_form_component(timezone)}" if timezone && !timezone.empty?
      uri = URI(url)
      response = Net::HTTP.get_response(uri)

      if response.code == "200"
        data = JSON.parse(response.body)
        return [] unless data.is_a?(Array) && !data.empty?

        data_hash = data[0]
        data_hash["data"] || []
      else
        []
      end
    rescue StandardError => e
      puts "Error fetching timeseries values for period: #{e.message}"
      []
    end

    # Calculate cumulative precipitation for different periods
    def get_cumulative_precipitation(ts_id, timezone = nil)
      # Get 7 days of data (covers all our periods)
      data = get_timeseries_values_for_period(ts_id, "P7D", timezone)
      return nil if data.empty?

      # Filter out invalid precipitation values (negative or extremely high)
      data = data.select do |row|
        val = row[1].to_f
        val >= 0 && val <= 200 # Filter out negative and extreme values
      end

      return nil if data.empty?

      now = Time.now.utc
      cumulatives = {}

      # Calculate cumulative values for each period
      periods = {
        "24h" => 24 * 60 * 60,
        "72h" => 72 * 60 * 60,
        "7d" => 7 * 24 * 60 * 60
      }

      periods.each do |label, seconds|
        cutoff = now - seconds
        values_in_period = data.select do |row|
          timestamp = begin
            Time.parse(row[0])
          rescue StandardError
            nil
          end
          timestamp && timestamp >= cutoff
        end
        # Sum all valid precipitation values
        total = values_in_period.sum { |row| row[1].to_f }
        cumulatives[label] = total
      end

      # Get the most recent timestamp and value for current reading
      latest = data.last
      {
        cumulatives: cumulatives,
        latest_value: latest ? latest[1] : nil,
        latest_timestamp: latest ? latest[0] : nil
      }
    rescue StandardError => e
      puts "Error calculating cumulative precipitation: #{e.message}"
      nil
    end

    # Get current data for a specific station by name
    def get_station_data(station_name, timezone = nil)
      # Get stations with coordinates
      uri = URI("#{api_base_url}?service=kisters&type=queryServices&request=getStationList&datasource=0&format=json&returnfields=station_name,station_no,station_latitude,station_longitude")
      response = Net::HTTP.get_response(uri)

      return nil if response.code != "200"

      data = JSON.parse(response.body)

      # Find the station_no and coordinates for this station name
      # Fields: station_name, station_no, station_latitude, station_longitude
      station_row = data.drop(1).find { |row| row[0] == station_name }
      return nil unless station_row

      station_no = station_row[1]
      latitude = station_row[2]
      longitude = station_row[3]

      # Get timeseries list for this station
      timeseries = get_timeseries_list(station_no)

      # Filter to include timeseries that are likely to have current data:
      # - NRT (Near Real-Time) timeseries
      # - PRODUCTION timeseries (typically real-time operational data)
      # Filter out historical archives like VAX, GRIFFS, etc. that may have stale data
      timeseries = timeseries.select do |ts|
        ts_name = ts[:ts_name]
        ts_name&.include?("NRT") || ts_name&.include?("PRODUCTION")
      end

      # Fetch latest values for relevant parameters
      measurements = []
      precipitation_ts = nil

      timeseries.each do |ts|
        # Check if this is a precipitation timeseries
        param_name = ts[:param_type_name]&.upcase
        param_longname = ts[:param_longname]&.downcase

        if param_name == "P" || param_name == "PN" || param_longname&.include?("precipitation")
          # Keep track of precipitation timeseries for cumulative calculation
          precipitation_ts = ts if precipitation_ts.nil?
          next # Skip adding individual hourly values
        end

        value = get_timeseries_value(ts[:ts_id], timezone)
        next unless value

        measurement = {
          parameter: ts[:param_longname] || ts[:param_name] || ts[:param_type_name],
          value: value[:value],
          unit: ts[:unit] || "",
          time: value[:timestamp]
        }

        # Add summer low percentage for flow measurements
        if param_name == "QR" || param_longname&.include?("flow")
          measurement[:summer_low_percent] = Grca.summer_low_percentage(station_name, value[:value].to_f)
        end

        measurements << measurement
      end

      # Calculate cumulative precipitation if available
      if precipitation_ts
        precip_data = get_cumulative_precipitation(precipitation_ts[:ts_id], timezone)
        if precip_data && precip_data[:cumulatives]
          unit = precipitation_ts[:unit] || "mm"
          # Add cumulative precipitation measurements
          measurements << {
            parameter: "Precipitation (24 hours)",
            value: precip_data[:cumulatives]["24h"]&.round(2),
            unit: unit,
            time: precip_data[:latest_timestamp]
          }
          measurements << {
            parameter: "Precipitation (72 hours)",
            value: precip_data[:cumulatives]["72h"]&.round(2),
            unit: unit,
            time: precip_data[:latest_timestamp]
          }
          measurements << {
            parameter: "Precipitation (7 days)",
            value: precip_data[:cumulatives]["7d"]&.round(2),
            unit: unit,
            time: precip_data[:latest_timestamp]
          }
        end
      end

      # Filter out invalid measurements (stale data, out-of-range values)
      measurements = measurements.map { |m| filter_valid_measurement(m) }.compact

      # Deduplicate measurements by parameter, keeping the most recent one
      measurements = measurements
                     .group_by { |m| m[:parameter] }
                     .map do |_, vals|
                       vals.max_by do |v|
                         v[:time]
                       end
      end

      # Custom sort: precipitation entries should appear in order 24h, 72h, 7d
      precipitation_order = {
        "Precipitation (24 hours)" => 1,
        "Precipitation (72 hours)" => 2,
        "Precipitation (7 days)" => 3
      }

      measurements = measurements.sort_by do |m|
        param = m[:parameter]
        # Use custom order for precipitation, otherwise sort alphabetically
        if precipitation_order.key?(param)
          [0, precipitation_order[param]]
        else
          [1, param]
        end
      end

      {
        name: station_name,
        station_no: station_no,
        latitude: latitude,
        longitude: longitude,
        measurements: measurements
      }
    rescue StandardError => e
      puts "Error fetching station data: #{e.message}"
      nil
    end

    # Get all stations with their coordinates
    def get_all_stations_with_coords
      uri = URI("#{api_base_url}?service=kisters&type=queryServices&request=getStationList&datasource=0&format=json&returnfields=station_name,station_no,station_latitude,station_longitude")
      response = Net::HTTP.get_response(uri)

      return [] if response.code != "200"

      data = JSON.parse(response.body)
      # Fields: station_name, station_no, station_latitude, station_longitude
      data.drop(1).map do |row|
        {
          name: row[0],
          station_no: row[1],
          latitude: row[2],
          longitude: row[3]
        }
      end
    rescue StandardError => e
      puts "Error fetching stations: #{e.message}"
      []
    end

    # Get a specific parameter value from all stations (optimized with batch queries)
    def get_parameter_across_stations(param_type, timezone = nil)
      stations = get_all_stations_with_coords
      return [] if stations.empty?

      # Batch fetch timeseries for all stations at once
      station_nos = stations.map { |s| s[:station_no] }.join(",")
      all_timeseries = get_timeseries_list(station_nos)

      # Filter to current data timeseries
      current_timeseries = all_timeseries.select do |ts|
        ts_name = ts[:ts_name]
        ts_name&.include?("NRT") || ts_name&.include?("PRODUCTION")
      end

      # Find matching timeseries for each station
      matching_ts_by_station = {}
      current_timeseries.each do |ts|
        next if matching_ts_by_station.key?(ts[:station_no])

        param_name = ts[:param_type_name]&.upcase
        param_longname = ts[:param_longname]&.downcase

        is_match = case param_type
                   when "temperature"
                     param_name == "AT" || param_longname&.include?("air temperature")
                   when "water_temperature"
                     param_name == "TW" || param_longname&.include?("water temperature")
                   when "stage"
                     param_name == "HG" || param_longname&.include?("stage")
                   when "flow"
                     param_name == "QR" || param_longname&.include?("flow")
                   when "precipitation"
                     param_name == "P" || param_name == "PN" || param_longname&.include?("precipitation")
                   when "reservoir_level"
                     param_name == "HK" || param_longname&.include?("reservoir elevation")
                   when "reservoir_volume"
                     param_name == "LS" || param_longname&.include?("reservoir storage")
                   else
                     param_longname&.include?(param_type.downcase)
                   end

        matching_ts_by_station[ts[:station_no]] = ts if is_match
      end

      # Batch fetch values for all matching timeseries
      ts_ids = matching_ts_by_station.values.map { |ts| ts[:ts_id] }
      return [] if ts_ids.empty?

      values_by_ts_id = get_timeseries_values_batch(ts_ids.join(","), timezone)

      # Build results
      results = []
      stations.each do |station|
        ts = matching_ts_by_station[station[:station_no]]
        next unless ts

        value = values_by_ts_id[ts[:ts_id]]
        next unless value

        result = {
          station_name: station[:name],
          station_no: station[:station_no],
          latitude: station[:latitude],
          longitude: station[:longitude],
          value: value[:value],
          unit: ts[:unit] || "",
          timestamp: value[:timestamp],
          parameter: ts[:param_longname] || ts[:param_name] || ts[:param_type_name]
        }

        # Add summer low percentage for flow parameter
        if param_type == "flow"
          result[:summer_low_percent] = Grca.summer_low_percentage(station[:name], value[:value].to_f)
        end

        results << result
      end

      # Filter out invalid measurements (stale data, out-of-range values)
      results = results.select do |r|
        !stale_timestamp?(r[:timestamp]) && valid_measurement_value?(r[:parameter], r[:value])
      end

      results.sort_by { |r| r[:station_name] }
    rescue StandardError => e
      puts "Error fetching parameter across stations: #{e.message}"
      []
    end

    # Get precipitation cumulative values across all stations (optimized with batch timeseries query)
    def get_precipitation_across_stations(timezone = nil)
      stations = get_all_stations_with_coords
      return [] if stations.empty?

      # Batch fetch timeseries for all stations at once
      station_nos = stations.map { |s| s[:station_no] }.join(",")
      all_timeseries = get_timeseries_list(station_nos)

      # Filter to current data timeseries and find precipitation timeseries per station
      station_precip_ts = {}
      all_timeseries.each do |ts|
        ts_name = ts[:ts_name]
        next unless ts_name&.include?("NRT") || ts_name&.include?("PRODUCTION")

        param_name = ts[:param_type_name]&.upcase
        param_longname = ts[:param_longname]&.downcase
        is_precip = param_name == "P" || param_name == "PN" || param_longname&.include?("precipitation")

        station_precip_ts[ts[:station_no]] = ts if is_precip && !station_precip_ts.key?(ts[:station_no])
      end

      results = []
      stations.each do |station|
        precip_ts = station_precip_ts[station[:station_no]]
        next unless precip_ts

        precip_data = get_cumulative_precipitation(precip_ts[:ts_id], timezone)
        next unless precip_data && precip_data[:cumulatives]

        results << {
          station_name: station[:name],
          station_no: station[:station_no],
          latitude: station[:latitude],
          longitude: station[:longitude],
          precip_24h: precip_data[:cumulatives]["24h"]&.round(2),
          precip_72h: precip_data[:cumulatives]["72h"]&.round(2),
          precip_7d: precip_data[:cumulatives]["7d"]&.round(2),
          unit: precip_ts[:unit] || "mm",
          timestamp: precip_data[:latest_timestamp]
        }
      end

      # Filter out stale data
      results = results.select { |r| !stale_timestamp?(r[:timestamp]) }

      results.sort_by { |r| r[:station_name] }
    rescue StandardError => e
      puts "Error fetching precipitation across stations: #{e.message}"
      []
    end

    # Home page with station selection form
    get "/" do
      @stations = get_stations
      erb :index
    end

    # Show station data (GET)
    get "/station" do
      station_name = params[:station]
      timezone = params[:timezone]
      @station_data = get_station_data(station_name, timezone)

      if @station_data
        erb :station
      else
        erb :error
      end
    end

    # Parameter overview routes
    get "/parameter/temperature" do
      timezone = params[:timezone]
      @parameter_data = get_parameter_across_stations("temperature", timezone)
      @parameter_name = "Air Temperature"
      erb :parameter
    end

    get "/parameter/water_temperature" do
      timezone = params[:timezone]
      @parameter_data = get_parameter_across_stations("water_temperature", timezone)
      @parameter_name = "Water Temperature"
      erb :parameter
    end

    get "/parameter/stage" do
      timezone = params[:timezone]
      @parameter_data = get_parameter_across_stations("stage", timezone)
      @parameter_name = "Stage (Water Level)"
      erb :parameter
    end

    get "/parameter/flow" do
      timezone = params[:timezone]
      @parameter_data = get_parameter_across_stations("flow", timezone)
      @parameter_name = "Flow"
      erb :parameter
    end

    get "/parameter/precipitation" do
      timezone = params[:timezone]
      @precipitation_data = get_precipitation_across_stations(timezone)
      erb :precipitation
    end

    # Lakes & Dams parameter routes
    get "/parameter/reservoir_level" do
      timezone = params[:timezone]
      @parameter_data = get_parameter_across_stations("reservoir_level", timezone)
      @parameter_name = "Reservoir Elevation"
      erb :parameter
    end

    get "/parameter/reservoir_volume" do
      timezone = params[:timezone]
      @parameter_data = get_parameter_across_stations("reservoir_volume", timezone)
      @parameter_name = "Reservoir Storage"
      erb :parameter
    end
  end
end
