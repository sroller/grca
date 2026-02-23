# frozen_string_literal: true

require "sinatra"
require "sinatra/base"
require_relative "cache"
require_relative "helpers"
require_relative "api_client"
require_relative "data_service"

module Grca
  class App < Sinatra::Base
    helpers Grca::Helpers

    # Use Thin in production, WEBrick for development
    begin
      require "thin"
      set :server, "thin"
    rescue LoadError
      set :server, "webrick"
    end

    set :bind, "0.0.0.0"
    set :port, 4567
    set :public_folder, File.join(File.dirname(__FILE__), "..", "..", "public")
    set :views, File.join(File.dirname(__FILE__), "..", "..", "views")

    # Initialize services
    def data_service
      @data_service ||= DataService.new(ApiClient.new)
    end

    # Index route - station list
    get "/" do
      @stations = data_service.get_stations
      erb :index
    end

    # Station detail route
    get "/station" do
      @stations = data_service.get_stations
      @station_name = params[:station]
      @station_data = data_service.get_station_data(@station_name, params[:timezone])

      if @station_data.nil? || @station_data.empty?
        redirect "/"
      else
        erb :station
      end
    end

    # Parameter overview routes
    get "/parameter/:type" do
      param_type = params[:type]
      timezone = params[:timezone]

      @parameter_data = data_service.get_parameter_across_stations(param_type, timezone)
      @parameter_name = format_parameter_name(param_type)

      erb :parameter
    end

    # Precipitation overview route
    get "/parameter/precipitation" do
      timezone = params[:timezone]
      @parameter_data = data_service.get_precipitation_across_stations(timezone)
      @parameter_name = "Precipitation"

      erb :precipitation
    end

    # Map view route
    get "/map" do
      @stations = data_service.get_all_stations_with_coords
      erb :map
    end

    # Admin route to clear cache
    get "/admin/clear_cache" do
      Grca::Cache.clear
      "Cache cleared"
    end

    private

    def format_parameter_name(param_type)
      param_type.to_s.split("_").map(&:capitalize).join(" ")
    end
  end
end
