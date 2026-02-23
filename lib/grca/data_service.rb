# frozen_string_literal: true

require_relative "api_client"

module Grca
  # Service layer for business logic and data processing
  class DataService
    def initialize(api_client = nil)
      @api_client = api_client || ApiClient.new
    end

    # Get all station names
    def get_stations
      Cache.fetch("station_list") do
        data = @api_client.get_station_list
        return [] unless data.is_a?(Array)
        
        data.drop(1).map { |row| row[0] }.sort
      end
    rescue StandardError => e
      puts "Error fetching stations: #{e.message}"
      []
    end

    # Get all stations with coordinates
    def get_all_stations_with_coords
      Cache.fetch("stations_with_coords") do
        returnfields = "station_name,station_no,station_latitude,station_longitude"
        data = @api_client.get_station_list(returnfields)
        return [] unless data.is_a?(Array)
        
        result = data.drop(1).map do |row|
          {
            name: row[0],
            station_no: row[1],
            latitude: row[2],
            longitude: row[3]
          }
        end
        
        result
      end.tap do |cached_result|
        if cached_result && !cached_result.empty?
          # Convert string keys back to symbols if needed (from JSON serialization)
          cached_result.map! do |station|
            if station.is_a?(Hash)
              station.transform_keys(&:to_sym)
            else
              station
            end
          end
        end
      end
    rescue StandardError => e
      puts "Error fetching stations: #{e.message}"
      []
    end

    # Get timeseries list for stations
    def get_timeseries_list(station_no)
      cache_key = "timeseries_list:#{station_no.to_s.split(",").sort.join(",")}"
      
      Cache.fetch(cache_key) do
        returnfields = "station_name,station_no,ts_id,ts_name,parametertype_id,parametertype_name,stationparameter_name,stationparameter_longname,ts_unitsymbol"
        data = @api_client.get_timeseries_list(station_no, returnfields)
        return [] unless data.is_a?(Array)
        
        result = data.drop(1).map do |row|
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
        
        result
      end.tap do |cached_result|
        if cached_result && !cached_result.empty?
          # Convert string keys back to symbols if needed (from JSON serialization)
          cached_result.map! do |ts|
            if ts.is_a?(Hash)
              ts.transform_keys(&:to_sym)
            else
              ts
            end
          end
        end
      end
    rescue StandardError => e
      puts "Error fetching timeseries list: #{e.message}"
      []
    end

    # Get latest value for a timeseries
    def get_timeseries_value(ts_id, timezone = nil)
      data = @api_client.get_timeseries_values(ts_id, timezone)
      return nil unless data.is_a?(Array) && !data.empty?
      
      data_hash = data[0]
      return nil unless data_hash["data"] && !data_hash["data"].empty?
      
      {
        timestamp: data_hash["data"][0][0],
        value: data_hash["data"][0][1]
      }
    rescue StandardError => e
      puts "Error fetching timeseries value: #{e.message}"
      nil
    end

    # Get latest values for multiple timeseries (batch)
    def get_timeseries_values_batch(ts_ids, timezone = nil)
      return {} if ts_ids.nil? || ts_ids.empty?
      
      cache_key = "ts_values:#{ts_ids.to_s.split(",").sort.join(",")}:#{timezone || 'utc'}"
      
      result = Cache.fetch(cache_key, ttl: 10 * 60) do
        data = @api_client.get_timeseries_values(ts_ids, timezone)
        return {} unless data.is_a?(Array)
        
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
      end
      
      # Convert any nested hashes with string keys to symbol keys (from JSON serialization)
      converted_result = {}
      result.each do |key, value_hash|
        if value_hash.is_a?(Hash)
          converted_result[key] = value_hash.transform_keys(&:to_sym)
        else
          converted_result[key] = value_hash
        end
      end
      
      converted_result
    rescue StandardError => e
      puts "Error fetching timeseries values batch: #{e.message}"
      {}
    end

    # Get timeseries values for a period
    def get_timeseries_values_for_period(ts_id, period, timezone = nil)
      cache_key = "ts_period:#{ts_id}:#{period}:#{timezone || 'utc'}"
      
      Cache.fetch(cache_key, ttl: 10 * 60) do
        data = @api_client.get_timeseries_values(ts_id, timezone, period)
        return [] unless data.is_a?(Array) && !data.empty?
        
        data_hash = data[0]
        data_hash["data"] || []
      end
    rescue StandardError => e
      puts "Error fetching timeseries values for period: #{e.message}"
      []
    end

    # Get station data for display
    def get_station_data(station_name, timezone = nil)
      stations = get_all_stations_with_coords
      station = stations.find { |s| s[:name] == station_name }
      return nil unless station
      
      all_timeseries = get_timeseries_list(station[:station_no])
      
      # Filter to current data timeseries
      current_timeseries = all_timeseries.select do |ts|
        ts_name = ts[:ts_name]
        ts_name&.include?("NRT") || ts_name&.include?("PRODUCTION")
      end
      
      # Deduplicate by parameter, keeping most recent
      deduplicated = {}
      current_timeseries.each do |ts|
        key = ts[:param_type_name]
        if deduplicated[key].nil? || ts[:ts_name]&.include?("NRT")
          deduplicated[key] = ts
        end
      end
      
      # Batch fetch values
      ts_ids = deduplicated.values.map { |ts| ts[:ts_id] }
      return [] if ts_ids.empty?
      
      values_by_ts_id = get_timeseries_values_batch(ts_ids.join(","), timezone)
      
      # Build measurements
      measurements = []
      deduplicated.values.each do |ts|
        value = values_by_ts_id[ts[:ts_id]]
        next unless value
        
        measurements << {
          parameter: ts[:param_longname] || ts[:param_name] || ts[:param_type_name],
          value: value[:value],
          unit: ts[:unit] || "",
          time: value[:timestamp]
        }
      end
      
      # Add cumulative precipitation
      precip_ts = current_timeseries.find do |ts|
        param_name = ts[:param_type_name]&.upcase
        param_longname = ts[:param_longname]&.downcase
        param_name == "P" || param_name == "PN" || param_longname&.include?("precipitation")
      end
      
      if precip_ts
        precip_data = get_cumulative_precipitation(precip_ts[:ts_id], timezone)
        if precip_data
          measurements << {
            parameter: "Precipitation (24 hours)",
            value: precip_data[:cumulatives]["24h"],
            unit: precip_data[:unit],
            time: precip_data[:latest_timestamp]
          }
          measurements << {
            parameter: "Precipitation (72 hours)",
            value: precip_data[:cumulatives]["72h"],
            unit: precip_data[:unit],
            time: precip_data[:latest_timestamp]
          }
          measurements << {
            parameter: "Precipitation (7 days)",
            value: precip_data[:cumulatives]["7d"],
            unit: precip_data[:unit],
            time: precip_data[:latest_timestamp]
          }
        end
      end
      
      # Filter invalid measurements
      measurements = measurements.map { |m| filter_valid_measurement(m) }.compact
      
      # Deduplicate by parameter
      measurements = measurements
                     .group_by { |m| m[:parameter] }
                     .map { |_, vals| vals.max_by { |v| v[:time] } }
      
      # Custom sort for precipitation
      precipitation_order = {
        "Precipitation (24 hours)" => 1,
        "Precipitation (72 hours)" => 2,
        "Precipitation (7 days)" => 3
      }
      
      measurements.sort_by do |m|
        if m[:parameter]&.start_with?("Precipitation")
          [0, precipitation_order[m[:parameter]] || 99]
        else
          [1, m[:parameter].to_s.downcase]
        end
      end
      
      # Return station data hash
      {
        name: station[:name],
        station_no: station[:station_no],
        latitude: station[:latitude],
        longitude: station[:longitude],
        measurements: measurements
      }
    end

    # Get parameter data across all stations
    def get_parameter_across_stations(param_type, timezone = nil)
      stations = get_all_stations_with_coords
      return [] if stations.empty?
      
      station_nos = stations.map { |s| s[:station_no] }.join(",")
      all_timeseries = get_timeseries_list(station_nos)
      
      # Filter to current data
      current_timeseries = all_timeseries.select do |ts|
        ts_name = ts[:ts_name]
        ts_name&.include?("NRT") || ts_name&.include?("PRODUCTION")
      end
      
      # Find matching timeseries
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
      
      # Batch fetch values
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
        
        # Add baseline percentage
        if param_type == "flow"
          result[:baseline_percent] = Grca.summer_low_percentage(station[:name], value[:value].to_f)
        elsif param_type == "stage"
          result[:baseline_percent] = Grca.stage_percentage(station[:name], value[:value].to_f)
        end
        
        results << result
      end
      
      # Filter invalid measurements
      results.select do |r|
        !stale_timestamp?(r[:timestamp]) && valid_measurement_value?(r[:parameter], r[:value])
      end.sort_by { |r| r[:station_name] }
    end

    # Get precipitation data across all stations
    def get_precipitation_across_stations(timezone = nil)
      stations = get_all_stations_with_coords
      return [] if stations.empty?
      
      station_nos = stations.map { |s| s[:station_no] }.join(",")
      all_timeseries = get_timeseries_list(station_nos)
      
      # Find precipitation timeseries per station
      station_precip_ts = {}
      all_timeseries.each do |ts|
        next unless ts[:ts_name]&.include?("NRT") || ts[:ts_name]&.include?("PRODUCTION")
        
        param_name = ts[:param_type_name]&.upcase
        param_longname = ts[:param_longname]&.downcase
        
        if param_name == "P" || param_name == "PN" || param_longname&.include?("precipitation")
          station_precip_ts[ts[:station_no]] ||= []
          station_precip_ts[ts[:station_no]] << ts
        end
      end
      
      # Build results
      results = []
      stations.each do |station|
        precip_ts_list = station_precip_ts[station[:station_no]]
        next unless precip_ts_list
        
        # Find best timeseries (prefer NRT)
        precip_ts = precip_ts_list.find { |ts| ts[:ts_name]&.include?("NRT") } || precip_ts_list.first
        precip_data = get_cumulative_precipitation(precip_ts[:ts_id], timezone)
        
        next unless precip_data
        
        results << {
          station_name: station[:name],
          station_no: station[:station_no],
          latitude: station[:latitude],
          longitude: station[:longitude],
          precip_24h: precip_data[:cumulatives]["24h"],
          precip_72h: precip_data[:cumulatives]["72h"],
          precip_7d: precip_data[:cumulatives]["7d"],
          unit: precip_data[:unit],
          timestamp: precip_data[:latest_timestamp]
        }
      end
      
      # Filter invalid
      results.select do |r|
        !stale_timestamp?(r[:timestamp]) &&
          r[:precip_24h] && r[:precip_72h] && r[:precip_7d]
      end.sort_by { |r| r[:station_name] }
    end

    private

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

    def valid_measurement_value?(param_type, value)
      return false if value.nil?
      
      param_type_lower = param_type.to_s.downcase
      val = value.to_f
      
      case param_type_lower
      when /air.*temp/, /^temperature$/
        val >= -60 && val <= 60
      when /water.*temp/
        val >= -5 && val <= 40
      when /stage/, /level/
        val >= -100 && val <= 1000
      when /flow/
        val >= 0 && val <= 100_000
      when /precip/
        val >= 0 && val <= 500
      else
        true
      end
    end

    def filter_valid_measurement(measurement)
      return nil if measurement.nil?
      return nil if stale_timestamp?(measurement[:time] || measurement[:timestamp])
      
      param = measurement[:parameter].to_s.downcase
      value = measurement[:value]
      
      return nil unless valid_measurement_value?(param, value)
      
      measurement
    end

    def get_cumulative_precipitation(ts_id, timezone = nil)
      data = get_timeseries_values_for_period(ts_id, "P7D", timezone)
      return nil if data.empty?
      
      # Filter invalid values
      data = data.select do |row|
        val = row[1].to_f
        val >= 0 && val <= 200
      end
      return nil if data.empty?
      
      now = Time.now.utc
      cumulatives = {}
      
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
            next false
          end
          timestamp >= cutoff
        end
        
        cumulatives[label] = values_in_period.sum { |row| row[1].to_f }.round(2)
      end
      
      {
        cumulatives: cumulatives,
        unit: "mm",
        latest_timestamp: data.max_by { |row| row[0] }&.[](0)
      }
    end
  end
end
