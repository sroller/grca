# frozen_string_literal: true

require "test_helper"

class TestGrca < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Grca::VERSION
  end

  def test_app_can_be_loaded
    assert_respond_to Grca::App, :run!
  end
end
