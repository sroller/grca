# GRCA - Grand River Conservation Authority

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

GRCA provides easy access to (near-)realtime sensor data from the Grand River Conservation Authority. This application presents a web interface to view current conditions from stations along the rivers in the Grand River watershed.

## Features

- Browse all available monitoring stations
- View current sensor data including:
  - Water level (HG - Water Level)
  - Water temperature (TW - Water Temperature)
  - Air temperature
  - Precipitation
  - And more...

## Installation

Clone the repository and install dependencies:

```bash
git clone https://github.com/[USERNAME]/grca.git
cd grca
bundle install
```

## Usage

### Running the Web Application

Start the Sinatra web server:

```bash
bundle exec ruby bin/grca_web
```

The application will be available at `http://localhost:4567`.

### Command Line Interface

The GRCA gem also provides a command-line interface for fetching station data:

```bash
bundle exec exe/grca
```

## API

This application uses the GRCA KiWIS API:

- Station List: `https://waterdata.grandriver.ca/KiWIS/KiWIS?service=kisters&type=queryServices&request=getStationList&datasource=0&format=json`
- Timeseries List: `https://waterdata.grandriver.ca/KiWIS/KiWIS?service=kisters&type=queryServices&request=getTimeseriesList&datasource=0&format=json&station_no=<station_no>`
- Timeseries Values: `https://waterdata.grandriver.ca/KiWIS/KiWIS?service=kisters&type=queryServices&request=getTimeseriesValues&datasource=0&format=json&ts_id=<ts_id>`

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

```bash
bundle exec rake test
```

To install this gem onto your local machine, run:

```bash
bundle exec rake install
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/grca.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in this project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/grca/blob/main/CODE_OF_CONDUCT.md).
