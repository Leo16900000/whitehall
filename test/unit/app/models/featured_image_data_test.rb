require "test_helper"

class FeaturedImageDataTest < ActiveSupport::TestCase
  test "rejects SVG logo uploads" do
    svg_image = File.open(Rails.root.join("test/fixtures/images/test-svg.svg"))
    image_data = build(:featured_image_data, file: svg_image)

    assert_not image_data.valid?
    assert_includes image_data.errors.map(&:full_message), "File You are not allowed to upload \"svg\" files, allowed types: jpg, jpeg, gif, png"
  end

  test "rejects non-image file uploads" do
    non_image_file = File.open(Rails.root.join("test/fixtures/folders.zip"))
    topical_event_featuring_image_data = build(:featured_image_data, file: non_image_file)

    assert_not topical_event_featuring_image_data.valid?
    assert_includes topical_event_featuring_image_data.errors.map(&:full_message), "File You are not allowed to upload \"zip\" files, allowed types: jpg, jpeg, gif, png"
  end

  test "should ensure that file is present" do
    topical_event_featuring_image_data = build(:featured_image_data, file: nil)

    assert_not topical_event_featuring_image_data.valid?
    assert_includes topical_event_featuring_image_data.errors.map(&:full_message), "File can't be blank"
  end

  test "accepts valid image uploads" do
    jpg_image = File.open(Rails.root.join("test/fixtures/big-cheese.960x640.jpg"))
    topical_event_featuring_image_data = build(:featured_image_data, file: jpg_image)

    assert topical_event_featuring_image_data
    assert_empty topical_event_featuring_image_data.errors
  end

  test "should ensure the image size to be 960x640" do
    image = File.open(Rails.root.join("test/fixtures/images/50x33_gif.gif"))
    topical_event_featuring_image_data = build(:featured_image_data, file: image)

    assert_not topical_event_featuring_image_data.valid?
    assert_includes topical_event_featuring_image_data.errors.map(&:full_message), "File is too small. Select an image that is 960 pixels wide and 640 pixels tall"
  end

  test "#all_asset_variants_uploaded? returns true if all assets present" do
    featured_image_data = build(:featured_image_data)

    assert featured_image_data.all_asset_variants_uploaded?
  end

  test "#all_asset_variants_uploaded? returns false if an asset variant is missing" do
    featured_image_data = build(:featured_image_data)
    featured_image_data.assets = []

    assert_not featured_image_data.all_asset_variants_uploaded?
  end
end
