## [0.1.1] - 2026-03-23

### Added
- River-based station views: browse flow, water temperature, and stage data grouped by river
- OSM service for water body identification from station coordinates (KiWIS site_name primary, Overpass API fallback)
- Rivers of interest filter (Grand River, Speed River, Nith River, Conestogo River)
- "Data by River" section on main page with navigation buttons
- "View by River" button on flow, water temperature, and stage parameter pages
- Multi-stage deployment support (prod, test, dev) with isolated caches and ports
- `--stage=` flag for rake deploy tasks (replaces STAGE env var)
- Ruby 4.0.1 compatibility (added logger gem dependency)

### Changed
- Cache directory now isolated per deployment instance via GRCA_INSTANCE env var
- Server port configurable via GRCA_PORT env var
- Deployment default stage changed from prod to dev
- Expanded reservoir storage value filter range to support all station values

## [Unreleased]

- Add Sinatra webapp with station selection form
- Display current sensor data from GRCA stations
- Use the KiWIS API endpoints from GRCA

## [0.1.0] - 2026-02-22

- Initial release
