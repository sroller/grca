# frozen_string_literal: true

module Grca
  # Summer low reference values for flow calculations
  # These values represent 70% of the summer low flow, measured on 2025-10-12
  # To calculate percentage of summer low: (current_flow / reference_value) * 70
  SUMMER_LOW_REFERENCE = {
    "Elmira" => 0.4061,
    "Below Elmira" => 1.7424,
    "Clair Creek" => 0.0559,
    "Drayton" => 0.0576,
    "Glen Allan" => 1.7721,
    "St. Jacobs" => 2.3972,
    "Eramosa" => 0.7475,
    "Bridgeport" => 7.3375,
    "Galt" => 13.51,
    "Doon" => 7.3857,
    "Dunnville upstream Weir 3" => 26.8433,
    "Hidden Valley" => 7.6353,
    "Bridgeport WQ Station" => 6.0891,
    "Victoria(Breslau) Continuous Station" => 8.7008,
    "Waldemar" => 1.5059,
    "West Montrose" => 4.0429,
    "York" => 18.7938,
    "York WQ Station" => 18.1311,
    "Below Shand" => 3.0868,
    "Dundalk" => 0.038,
    "Leggatt" => 0.9132,
    "Marsville" => 1.0688,
    "Keldon" => 0.06,
    "Erbsville" => 0.0207,
    "Weber Street" => 0.1204,
    "Mill Creek" => 0.7136,
    "Moorefield" => 0.0751,
    "Nithburg" => 0.0051,
    "Ayr" => 1.268,
    "New Hamburg" => 0.5309,
    "Philipsburg" => 0.3125,
    "Canning" => 1.9323,
    "Schneider Creek" => 0.1465,
    "Beaverdale" => 3.0726,
    "Hanlon" => 1.6401,
    "Road 32 WQ Station" => 2.9428,
    "Victoria Road" => 0.7817,
    "Armstrong Mills" => 0.2043,
    "Willow Brook" => 0.042,
    "Mount Vernon" => 0.4152,
    "Aberfoyle" => 0.1749,
    "Floradale" => 0.0567,
    "McKenzie Creek" => 0.0933,
    "Horner Creek" => 0.1452,
    "Fairchild near Brantford" => 0.6613,
    "New Dundee Road" => 0.0,
    "Dickie Settlement Road" => 0.1735
  }.freeze

  # Calculate the percentage of summer low flow
  # @param station_name [String] The station name
  # @param current_flow [Float] The current flow value
  # @return [Float, nil] The percentage of summer low flow, or nil if no reference
  def self.summer_low_percentage(station_name, current_flow)
    return nil if current_flow.nil? || current_flow.zero?

    reference = SUMMER_LOW_REFERENCE[station_name]
    return nil if reference.nil? || reference.zero?

    # reference is 70% of summer low, so:
    # percentage = (current / reference) * 70
    ((current_flow / reference) * 70).round(1)
  end
end
