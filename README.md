# GRCA - Grand River Conservation Authority

GRCA provides easy access to (near-)realtime sensor data from the Grand River Conservation Authority. This application presents a web interface to view current conditions from stations along the rivers in the Grand River watershed.

## Features

- Browse all available monitoring stations
- View current sensor data including:
  - Water level (stage)
  - Water temperature
  - Air temperature
  - Flow
  - Precipitation (with 24h, 72h, 7d cumulative columns)
- Reservoir monitoring (elevation and storage volume with historical deltas)
- River-based station views: browse data grouped by river (Grand, Speed, Nith, Conestogo)
- Interactive station map with Leaflet and Google Maps
- Parameter overview pages across all stations

## Installation

Clone the repository and install dependencies:

```bash
git clone https://github.com/sroller/grca.git
cd grca
bundle install
```

Requires Ruby 4.0.1+ with RVM.

## Usage

### Running the Web Application

Start the web server:

```bash
bundle exec ruby bin/grca_web
```

The application will be available at `http://localhost:4567`.

### Deployment

Three deployment stages are supported: `prod`, `test`, and `dev`.

```bash
# Deploy to dev (default)
rvmsudo rake deploy:copy_files

# Deploy to a specific stage
rvmsudo rake deploy:copy_files -- --stage=prod
rvmsudo rake deploy:copy_files -- --stage=test

# Show full deployment guide for a stage
rake deploy:all -- --stage=prod
```

Each stage runs on an isolated port with separate cache directories:

| Stage | Port | Directory | Service |
|-------|------|-----------|---------|
| prod  | 4567 | /var/www/grca | grca.service |
| test  | 4568 | /var/www/grca-test | grca-test.service |
| dev   | 4569 | /var/www/grca-dev | grca-dev.service |

## API

This application uses the GRCA KiWIS API:

- Station List: `https://waterdata.grandriver.ca/KiWIS/KiWIS?service=kisters&type=queryServices&request=getStationList&datasource=0&format=json`
- Timeseries List: `https://waterdata.grandriver.ca/KiWIS/KiWIS?service=kisters&type=queryServices&request=getTimeseriesList&datasource=0&format=json&station_no=<station_no>`
- Timeseries Values: `https://waterdata.grandriver.ca/KiWIS/KiWIS?service=kisters&type=queryServices&request=getTimeseriesValues&datasource=0&format=json&ts_id=<ts_id>`

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests.

```bash
bundle exec rake test
```
