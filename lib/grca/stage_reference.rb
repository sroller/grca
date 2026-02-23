# frozen_string_literal: true

module Grca
  # Stage reference values for percentage calculations
  # These values represent 70% of the baseline stage, measured on 2025-10-12
  # To calculate percentage of baseline: (current_stage / reference_value) * 70
  STAGE_REFERENCE = {
    "Weber Street" => 0.7547,
    "Marsville" => 0.2909,
    "Hanlon" => 0.5801,
    "New Hamburg" => 1.5719,
    "West Montrose" => 0.125,
    "Hidden Valley" => 4.0222,
    "McKenzie Creek" => 1.1584,
    "Sulphur Creek d/s fish ladder" => 174.1744,
    "Galt" => 0.2288,
    "York" => 0.7511,
    "Nithburg" => 0.4606,
    "Philipsburg" => 0.0976,
    "Mill Creek" => 1.1983,
    "Glen Allan" => 0.6428,
    "Moorefield" => 0.4178,
    "Victoria Road" => 0.56,
    "Erbsville" => 0.1957,
    "Schneider Creek" => 0.5099,
    "Keldon" => 0.3729,
    "Leggatt" => 0.316,
    "Waldemar" => 0.2846,
    "Hanlon WQ Station" => 0.5801,
    "Road 32 WQ Station" => 0.1444,
    "Victoria(Breslau) Continuous Station" => 0.6728,
    "York WQ Station" => 0.7518,
    "Floradale" => 0.1703,
    "Fairchild near Brantford" => 1.3997,
    "St. Jacobs" => 0.2347,
    "Elmira" => 0.1913,
    "Below Elmira" => 9.8073,
    "Clair Creek" => 0.2629,
    "Drayton" => 0.587,
    "Eramosa" => 0.3429,
    "Brantford" => 0.2079,
    "Brant WQ Station" => 0.8433,
    "Bridgeport" => 0.336,
    "Doon" => 0.4135,
    "Dunnville upstream Weir 3" => 175.938,
    "Bridgeport WQ Station" => 0.159,
    "Below Shand" => 0.3311,
    "Dundalk" => 1.222,
    "Canning" => 0.3922,
    "Ayr" => 0.4624,
    "Armstrong Mills" => 0.4094,
    "Beaverdale" => 0.6408,
    "Aberfoyle" => 0.3715,
    "Mount Vernon" => 1.0435
  }.freeze

  # Calculate the percentage of baseline stage
  # @param station_name [String] The station name
  # @param current_stage [Float] The current stage value
  # @return [Integer, nil] The percentage of baseline stage, or nil if no reference
  def self.stage_percentage(station_name, current_stage)
    return nil if current_stage.nil? || current_stage.zero?

    reference = STAGE_REFERENCE[station_name]
    return nil if reference.nil? || reference.zero?

    # reference is 70% of baseline, so:
    # percentage = (current / reference) * 70
    ((current_stage / reference) * 70).round.to_i
  end
end
