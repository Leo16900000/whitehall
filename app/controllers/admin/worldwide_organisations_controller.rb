class Admin::WorldwideOrganisationsController < Admin::BaseController
  VERSIONS_PER_PAGE = 10

  respond_to :html

  before_action :find_worldwide_organisation, except: %i[index new create]
  layout :get_layout

  def index
    @worldwide_organisations = WorldwideOrganisation.ordered_by_name
    render_design_system(:index, :legacy_index)
  end

  def new
    @worldwide_organisation = WorldwideOrganisation.new
    @worldwide_organisation.build_default_news_image
    respond_with :admin, @worldwide_organisation
  end

  def create
    @worldwide_organisation = WorldwideOrganisation.create(worldwide_organisation_params) # rubocop:disable Rails/SaveBang
    respond_with :admin, @worldwide_organisation
    flash[:notice] = "Organisation created successfully"
  end

  def edit
    @worldwide_organisation.build_default_news_image
    respond_with :admin, @worldwide_organisation
  end

  def update
    @worldwide_organisation.update!(worldwide_organisation_params)
    respond_with :admin, @worldwide_organisation
  end

  def show
    @versions = @worldwide_organisation
                  .versions_desc
                  .page(params[:page])
                  .per(VERSIONS_PER_PAGE)
    render_design_system(:show, :legacy_show)
  end

  def access_info
    @access_and_opening_times = @worldwide_organisation.default_access_and_opening_times
  end

  def set_main_office
    org_params = params.require(:worldwide_organisation).permit(:main_office_id)
    if @worldwide_organisation.update(org_params)
      flash[:notice] = "Main office updated successfully"
    end
    respond_with :admin, @worldwide_organisation, WorldwideOffice
  end

  def confirm_destroy; end

  def destroy
    @worldwide_organisation.destroy!
    respond_with :admin, @worldwide_organisation
    flash[:notice] = "Organisation deleted successfully"
  end

private

  def get_layout
    design_system_actions = %w[confirm_destroy]
    design_system_actions += %w[index show] if preview_design_system?(next_release: false)

    if design_system_actions.include?(action_name)
      "design_system"
    else
      "admin"
    end
  end

  def find_worldwide_organisation
    @worldwide_organisation = WorldwideOrganisation.friendly.find(params[:id])
  end

  def worldwide_organisation_params
    params.require(:worldwide_organisation).permit(
      :name,
      :logo_formatted_name,
      world_location_ids: [],
      sponsoring_organisation_ids: [],
      default_news_image_attributes: %i[file file_cache],
    )
  end
end
