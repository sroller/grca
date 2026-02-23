# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require_relative "cache"

module Grca
  # Client for interacting with the GRCA KiWIS API
  class ApiClient
    attr_reader :base_url

    def initialize(base_url = "https://waterdata.grandriver.ca/KiWIS/KiWIS")
      @base_url = base_url
    end

    # Make an HTTP GET request to the API
    def get(params)
      uri = build_uri(params)
      response = Net::HTTP.get_response(uri)
      
      if response.code == "200"
        JSON.parse(response.body)
      else
        nil
      end
    rescue StandardError => e
      puts "API Error: #{e.message}"
      nil
    end

    # Get station list
    def get_station_list(returnfields = nil)
      params = {
        service: "kisters",
        type: "queryServices",
        request: "getStationList",
        datasource: "0",
        format: "json"
      }
      params[:returnfields] = returnfields if returnfields
      
      get(params)
    end

    # Get station info by station_no
    def get_station_info(station_no)
      params = {
        service: "kisters",
        type: "queryServices",
        request: "getStationInfo",
        datasource: "0",
        format: "json",
        station_no: station_no
      }
      
      get(params)
    end

    # Get timeseries list for stations
    def get_timeseries_list(station_nos, returnfields = nil)
      params = {
        service: "kisters",
        type: "queryServices",
        request: "getTimeseriesList",
        datasource: "0",
        format: "json",
        station_no: station_nos
      }
      params[:returnfields] = returnfields if returnfields
      
      get(params)
    end

    # Get timeseries values
    def get_timeseries_values(ts_ids, timezone = nil, period = nil)
      params = {
        service: "kisters",
        type: "queryServices",
        request: "getTimeseriesValues",
        datasource: "0",
        format: "json",
        ts_id: ts_ids
      }
      params[:timezone] = timezone if timezone && !timezone.empty?
      params[:period] = period if period
      
      get(params)
    end

    private

    def build_uri(params)
      query_string = params.map { |k, v| "#{k}=#{URI.encode_www_form_component(v)}" }.join("&")
      URI("#{base_url}?#{query_string}")
    end
  end
end
