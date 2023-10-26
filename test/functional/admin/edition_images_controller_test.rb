require "test_helper"

class Admin::EditionImagesControllerTest < ActionDispatch::IntegrationTest
  extend Minitest::Spec::DSL

  test "forbids unauthorised users from viewing the images index endpoint" do
    edition = create(:draft_publication)
    user = create(:world_editor)
    login_as user
    get admin_edition_images_path(edition.id)
    assert_equal 403, status
  end

  test "edit page displays alt text input for images with alt text" do
    login_authorised_user
    images = [build(:image)]
    edition = create(:draft_publication, images:)
    get edit_admin_edition_image_path(edition, images[0])
    assert_select "#image_alt_text"
  end

  test "edit page does not display alt text input where it is blank" do
    login_authorised_user
    images = [build(:image, alt_text: "")]
    edition = create(:draft_publication, images:)
    get edit_admin_edition_image_path(edition, images[0])
    assert_select "#image_alt_text", count: 0
  end

  test "#create redirects to #edit with a valid image upload" do
    login_authorised_user
    edition = create(:news_article)

    file = upload_fixture("images/960x640_jpeg.jpg")
    post admin_edition_images_path(edition), params: { image: { image_data: { file: } } }

    follow_redirect!
    assert_equal edit_admin_edition_image_path(edition, edition.images.last), path
  end

  test "#create updates the lead_image association if edition can have a custom lead image" do
    login_authorised_user
    edition = create(:news_article)

    file = upload_fixture("images/960x640_jpeg.jpg")
    post admin_edition_images_path(edition), params: { image: { image_data: { file: } } }

    assert_equal "960x640_jpeg.jpg", edition.lead_image.filename
  end

  test "#create shows the cropping page if image is too large" do
    login_authorised_user
    edition = create(:news_article)

    filename = "images/960x960_jpeg.jpg"
    post admin_edition_images_path(edition), params: { image: { image_data: { file: upload_fixture(filename, "image/jpeg") } } }

    assert_template "admin/edition_images/crop"
    assert_select "h1", "Crop image"

    img = document_root_element.css("img.app-c-image-cropper__image").first
    expected_data_url = "data:image/jpeg;base64,#{Base64.strict_encode64(file_fixture(filename).read)}"
    assert_equal expected_data_url, img["src"], "Expected img src to be a Data URL representation of the uploaded file"
  end

  test "#create shows a validation error if image is too small" do
    login_authorised_user
    edition = create(:news_article)

    file = upload_fixture("images/50x33_gif.gif")
    post admin_edition_images_path(edition), params: { image: { image_data: { file: } } }

    assert_template "admin/edition_images/index"
    assert_select ".govuk-error-summary li", "Image data file is too small. Select an image that is 960 pixels wide and 640 pixels tall"
  end

  test "#create shows a validation error if image has a duplicated filename" do
    login_authorised_user
    edition = create(:news_article)
    file = upload_fixture("images/960x640_gif.gif")
    create(:image, edition:, image_data: build(:image_data, file:))

    post admin_edition_images_path(edition), params: { image: { image_data: { file: } } }

    assert_template "admin/edition_images/index"
    assert_select ".govuk-error-summary li", "Image data file name is not unique. All your file names must be different. Do not use special characters to create another version of the same file name."
  end

  test "POST :create triggers a job be queued to store image and variants in Asset Manager" do
    login_authorised_user

    edition = create(:news_article)
    file = upload_fixture("images/960x640_jpeg.jpg")
    model_type = ImageData.to_s
    variants = Asset.variants.values

    AssetManagerCreateAssetWorker
      .expects(:perform_async)
      .with(anything, has_entries("assetable_id" => kind_of(Integer), "asset_variant" => any_of(*variants), "assetable_type" => model_type), anything, anything, anything, anything).times(7)

    post admin_edition_images_path(edition), params: { image: { image_data: { file: } } }
  end

  def login_authorised_user
    user = create(:gds_editor)
    login_as user
  end
end
