require "test_helper"

class Admin::OrganisationsControllerTest < ActionController::TestCase
  setup do
    login_as_preview_design_system_user :gds_admin
  end

  should_be_an_admin_controller
  should_render_bootstrap_implementation_with_preview_next_release

  def example_organisation_attributes
    attributes_for(:organisation).except(:logo, :analytics_identifier)
  end

  test "GET on :index assigns all organisations in alphabetical order" do
    organisation2 = create(:organisation, name: "org 2")
    organisation1 = create(:organisation, name: "org 1")
    get :index

    assert_response :success
    assert_template :index
    assert_equal [organisation1, organisation2], assigns(:organisations)
  end

  test "GET on :new denied if not a gds admin" do
    login_as_preview_design_system_user :writer
    get :new
    assert_response :forbidden
  end

  test "POST on :create denied if not a gds admin" do
    login_as_preview_design_system_user :writer
    post :create, params: { organisation: {} }
    assert_response :forbidden
  end

  view_test "Link to create organisation does not show if not a gds admin" do
    login_as_preview_design_system_user :writer
    get :index
    refute_select ".govuk-button", text: "Create new organisation"
  end

  view_test "Link to create organisation shows if a gds admin" do
    get :index
    assert_select ".govuk-button", text: "Create new organisation"
  end

  test "POST on :create saves the organisation and its associations" do
    attributes = example_organisation_attributes

    parent_org1 = create(:organisation)
    parent_org2 = create(:organisation)

    post :create,
         params: {
           organisation: attributes
                           .merge(
                             parent_organisation_ids: [parent_org1.id, parent_org2.id],
                             organisation_type_key: :executive_agency,
                             govuk_status: "exempt",
                             featured_links_attributes: {
                               "0" => {
                                 url: "http://www.gov.uk/mainstream/something",
                                 title: "Something on mainstream",
                               },
                             },
                           ),
         }

    assert_redirected_to admin_organisations_path
    assert organisation = Organisation.last
    assert organisation.topical_event_organisations.map(&:ordering).all?(&:present?), "no ordering"
    assert_equal organisation.topical_event_organisations.map(&:ordering).sort, organisation.topical_event_organisations.map(&:ordering).uniq.sort
    assert organisation_top_task = organisation.featured_links.last
    assert_equal "http://www.gov.uk/mainstream/something", organisation_top_task.url
    assert_equal "Something on mainstream", organisation_top_task.title
    assert_same_elements [parent_org1, parent_org2], organisation.parent_organisations
    assert_equal OrganisationType.executive_agency, organisation.organisation_type
    assert_equal "exempt", organisation.govuk_status
  end

  test "POST :create can set a custom logo" do
    post :create,
         params: {
           organisation: example_organisation_attributes
                           .merge(
                             organisation_logo_type_id: OrganisationLogoType::CustomLogo.id,
                             logo: upload_fixture("logo.png", "image/png"),
                           ),
         }

    assert_match %r{logo.png}, Organisation.last.logo.file.filename
  end

  test "POST create can set number of important board members" do
    post :create,
         params: {
           organisation: example_organisation_attributes
                           .merge(important_board_members: 1),
         }

    assert_equal 1, Organisation.last.important_board_members
  end

  test "POST on :create with invalid data re-renders the new form" do
    attributes = example_organisation_attributes

    assert_no_difference("Organisation.count") do
      post :create, params: { organisation: attributes.merge(name: "") }
    end
    assert_response :success
    assert_template :new
  end

  test "GET on :show loads the organisation and renders the show template" do
    organisation = create(:organisation)
    get :show, params: { id: organisation }

    assert_response :success
    assert_template :show
  end

  test "GET on :edit loads the organisation and renders the edit template" do
    organisation = create(:organisation)
    get :edit, params: { id: organisation }

    assert_response :success
    assert_template :edit
    assert_equal organisation, assigns(:organisation)
  end

  view_test "GET on :edit allows entry of important board members only data to Editors and above" do
    organisation = create(:organisation)
    junior_board_member_role = create(:board_member_role)
    senior_board_member_role = create(:board_member_role)

    create(:organisation_role, organisation:, role: senior_board_member_role)
    create(:organisation_role, organisation:, role: junior_board_member_role)

    managing_editor = create(:managing_editor, :with_preview_design_system, organisation:)
    departmental_editor = create(:departmental_editor, :with_preview_design_system, organisation:)
    world_editor = create(:world_editor, :with_preview_design_system, organisation:)

    get :edit, params: { id: organisation }
    assert_select "select#organisation_important_board_members option", count: 2

    login_as(departmental_editor)
    get :edit, params: { id: organisation }
    assert_select "select#organisation_important_board_members option", count: 2

    login_as(managing_editor)
    get :edit, params: { id: organisation }
    assert_select "select#organisation_important_board_members option", count: 2

    login_as(world_editor)
    get :edit, params: { id: organisation }
    assert_select "select#organisation_important_board_members option", count: 0
  end

  test "PUT on :update allows updating of organisation role ordering" do
    organisation = create(:organisation)
    ministerial_role = create(:ministerial_role)
    organisation_role = create(:organisation_role, organisation:, role: ministerial_role, ordering: 1)

    put :update,
        params: { id: organisation.id,
                  organisation: { organisation_roles_attributes: {
                    "0" => { id: organisation_role.id, ordering: "2" },
                  } } }

    assert_equal 2, organisation_role.reload.ordering
  end

  test "PUT :update can set a custom logo" do
    organisation = create(:organisation)
    put :update,
        params: { id: organisation,
                  organisation: {
                    organisation_logo_type_id: OrganisationLogoType::CustomLogo.id,
                    logo: upload_fixture("logo.png"),
                  } }
    assert_match %r{logo.png}, organisation.reload.logo.file.filename
  end

  test "PUT :update can set default news image" do
    organisation = create(:organisation)
    put :update,
        params: { id: organisation,
                  organisation: {
                    default_news_image_attributes: {
                      file: upload_fixture("minister-of-funk.960x640.jpg"),
                    },
                  } }
    assert_equal "minister-of-funk.960x640.jpg", organisation.reload.default_news_image.file.file.filename
  end

  test "PUT on :update with bad params does not update the organisation and renders the edit page" do
    ministerial_role = create(:ministerial_role)
    organisation = create(:organisation, name: "org name")
    create(:organisation_role, organisation:, role: ministerial_role)

    put :update, params: { id: organisation, organisation: { name: "" } }

    assert_response :success
    assert_template :edit

    assert_equal "org name", organisation.reload.name
  end

  test "PUT on :update should modify the organisation" do
    organisation = create(:organisation, name: "Ministry of Sound")
    organisation_attributes = {
      name: "Ministry of Noise",
    }

    put :update, params: { id: organisation, organisation: organisation_attributes }

    organisation.reload
    assert_equal "Ministry of Noise", organisation.name
  end

  test "PUT on :update handles non-departmental public body information" do
    organisation = create(:organisation)

    put :update,
        params: { id: organisation,
                  organisation: {
                    ocpa_regulated: "false",
                    public_meetings: "true",
                    public_minutes: "true",
                    regulatory_function: "false",
                  } }

    organisation.reload

    assert_response :redirect
    assert_not organisation.ocpa_regulated?
    assert organisation.public_meetings?
    assert organisation.public_minutes?
    assert_not organisation.regulatory_function?
  end

  test "PUT on :update handles existing featured link attributes" do
    organisation = create(:organisation)
    featured_link = create(:featured_link, linkable: organisation)

    put :update,
        params: { id: organisation,
                  organisation: { featured_links_attributes: { "0" => {
                    id: featured_link.id,
                    title: "New title",
                    url: featured_link.url,
                    _destroy: "false",
                  } } } }

    assert_response :redirect
    assert_equal "New title", featured_link.reload.title
  end

  view_test "Prevents unauthorized management of homepage priority" do
    organisation = create(:organisation)
    writer = create(:writer, :with_preview_design_system, organisation:)
    login_as(writer)

    get :edit, params: { id: organisation }
    refute_select ".homepage-priority"

    managing_editor = create(:managing_editor, :with_preview_design_system, organisation:)
    login_as(managing_editor)
    get :edit, params: { id: organisation }
    assert_select ".homepage-priority"

    gds_editor = create(:gds_editor, :with_preview_design_system, organisation:)
    login_as(gds_editor)
    get :edit, params: { id: organisation }
    assert_select ".homepage-priority"
  end

  test "Non-admins can only edit their own organisations or children" do
    organisation1 = create(:organisation)
    gds_editor = create(:gds_editor, :with_preview_design_system, organisation: organisation1)
    login_as(gds_editor)

    get :edit, params: { id: organisation1 }
    assert_response :success

    organisation2 = create(:organisation)
    get :edit, params: { id: organisation2 }
    assert_response 403

    organisation2.parent_organisations << organisation1
    get :edit, params: { id: organisation2 }
    assert_response :success
  end

  view_test "GET :features copes with topical events that have no dates" do
    topical_event = create(:topical_event)
    organisation = create(:organisation)
    feature_list = organisation.load_or_create_feature_list("en")
    feature_list.features.create!(
      topical_event:,
      image: image_fixture_file,
      alt_text: "Image alternative text",
    )

    get :features, params: { id: organisation, locale: "en" }
    assert_response :success
  end

  view_test "GET :features without an organisation defaults to the user organisation" do
    organisation = create(:organisation)

    get :features, params: { id: organisation, locale: "en" }
    assert_response :success

    selected_organisation = css_select('#organisation_filter option[selected="selected"]')
    assert_equal selected_organisation.text, organisation.name
  end

  view_test "GDS Editors can set political status" do
    organisation = create(:organisation)
    writer = create(:writer, :with_preview_design_system, organisation:)
    login_as(writer)

    get :edit, params: { id: organisation }
    refute_select ".political-status"

    managing_editor = create(:managing_editor, :with_preview_design_system, organisation:)
    login_as(managing_editor)
    get :edit, params: { id: organisation }
    refute_select ".political-status"

    gds_editor = create(:gds_editor, :with_preview_design_system, organisation:)
    login_as(gds_editor)
    get :edit, params: { id: organisation }
    assert_select ".political-status"
  end

  view_test "the featurables tab should display information regarding max documents" do
    first_feature = build(:feature, document: create(:published_case_study).document, ordering: 1)
    organisation = create(:organisation)
    create(:feature_list, locale: :en, featurable: organisation, features: [first_feature])
    get :features, params: { id: organisation }

    assert_match(/A maximum of 6 documents will be featured on GOV.UK.*/, response.body)
  end

  test "POST : create calls worker with asset args if use_non_legacy_endpoints is true" do
    setup_user_with_required_permission

    model_type = Organisation.to_s
    variant = Asset.variants[:original]

    AssetManagerCreateAssetWorker
      .expects(:perform_async)
      .with(anything, has_entries("assetable_id" => kind_of(Integer), "asset_variant" => variant, "assetable_type" => model_type), anything, anything, anything, anything)

    post :create,
         params: {
           organisation: example_organisation_attributes
                           .merge(
                             organisation_logo_type_id: OrganisationLogoType::CustomLogo.id,
                             logo: upload_fixture("logo.png", "image/png"),
                           ),
         }
  end

  def setup_user_with_required_permission
    @current_user.permissions << User::Permissions::USE_NON_LEGACY_ENDPOINTS
  end
end
