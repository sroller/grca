# Project
GRCA - gives easy access to (near-)realtime sensor data from the Grand River Conservation Authority

## Target
- using the ReST api under https://data.grandriver.ca/webservices-monitoring.html
- there is a list of stations along the rivers
- each station offers a different variety of sensor data
- we're interested in water level, air temperature, water temperatur, precipitation
- we want a web app that offers a simple access to consolidated data for the rivers in the Grand River watershed


## Techstack
- ruby with Sinatra as webframework
- use minitest and SimpleCov for testing
- use rubocop for linting
- the project should become a Ruby Gem

## URLs
- list of all stations: https://waterdata.grandriver.ca/KiWIS/KiWIS?service=kisters&type=queryServices&request=getStationList&datasource=0&format=json
- list of all timeseries for a single station: https://waterdata.grandriver.ca/KiWIS/KiWIS?service=kisters&type=queryServices&request=getTimeseriesList&datasource=0&format=json&station_no=<station_no>

## Conventions
- document all changes in the CHANGES file in the root of the project
- use git for version management
