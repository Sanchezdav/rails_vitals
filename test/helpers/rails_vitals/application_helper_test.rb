require "test_helper"

class RailsVitalsApplicationHelperTest < ActionView::TestCase
  include RailsVitals::ApplicationHelper

  test "#score_color returns hex color String mapped from scorer color token" do
    assert_equal RailsVitals::ApplicationHelper::COLOR_GREEN, score_color("green")
    assert_equal RailsVitals::ApplicationHelper::COLOR_BLUE, score_color("blue")
    assert_equal RailsVitals::ApplicationHelper::COLOR_AMBER, score_color("amber")
    assert_equal RailsVitals::ApplicationHelper::COLOR_RED, score_color("unknown")
  end

  test "#score_label_to_color returns healthy acceptable warning critical bracket label by numeric score" do
    assert_equal "healthy", score_label_to_color(90)
    assert_equal "acceptable", score_label_to_color(70)
    assert_equal "warning", score_label_to_color(50)
    assert_equal "critical", score_label_to_color(49)
  end

  test "#callback_color returns hex color by callback kind symbol" do
    assert_equal RailsVitals::ApplicationHelper::COLOR_BLUE, callback_color(:validation)
    assert_equal RailsVitals::ApplicationHelper::COLOR_GREEN, callback_color(:create)
    assert_equal RailsVitals::ApplicationHelper::COLOR_RED, callback_color(:destroy)
    assert_equal RailsVitals::ApplicationHelper::COLOR_GRAY, callback_color(:unknown)
  end

  test "#query_heat_color #time_heat_color and #n1_heat_color return low medium high intensity hex color" do
    assert_equal RailsVitals::ApplicationHelper::COLOR_LIGHT_GREEN, query_heat_color(9)
    assert_equal RailsVitals::ApplicationHelper::COLOR_ORANGE, query_heat_color(10)
    assert_equal RailsVitals::ApplicationHelper::COLOR_LIGHT_RED, query_heat_color(25)

    assert_equal RailsVitals::ApplicationHelper::COLOR_LIGHT_GREEN, time_heat_color(99)
    assert_equal RailsVitals::ApplicationHelper::COLOR_ORANGE, time_heat_color(100)
    assert_equal RailsVitals::ApplicationHelper::COLOR_LIGHT_RED, time_heat_color(500)

    assert_equal RailsVitals::ApplicationHelper::COLOR_LIGHT_GREEN, n1_heat_color(24.9)
    assert_equal RailsVitals::ApplicationHelper::COLOR_ORANGE, n1_heat_color(25)
    assert_equal RailsVitals::ApplicationHelper::COLOR_LIGHT_RED, n1_heat_color(75)
  end
end
