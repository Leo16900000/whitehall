class Admin::ClassificationFeaturingsController < Admin::BaseController
  before_action :load_classification

  def index
    filter_params = params.slice(:page, :type, :author, :organisation, :title)
                          .permit!
                          .to_h
                          .merge(state: "published", classification: @topical_event.to_param)

    @filter = Admin::EditionFilter.new(Edition, current_user, filter_params)
    @tagged_editions = editions_to_show

    @classification_featurings = @topical_event.classification_featurings
    @featurable_offsite_links = @topical_event.offsite_links

    if request.xhr?
      render partial: "admin/classification_featurings/featured_documents"
    else
      render :index
    end
  end

  def new
    featured_edition = Edition.find(params[:edition_id]) if params[:edition_id].present?
    featured_offsite_link = OffsiteLink.find(params[:offsite_link_id]) if params[:offsite_link_id].present?
    @classification_featuring = @topical_event.classification_featurings.build(edition: featured_edition, offsite_link: featured_offsite_link)
    @classification_featuring.build_image
  end

  def create
    @classification_featuring = @topical_event.feature(classification_featuring_params)
    if @classification_featuring.valid?
      flash[:notice] = if featuring_a_document?
                         "#{@classification_featuring.edition.title} has been featured on #{@topical_event.name}"
                       else
                         "#{@classification_featuring.offsite_link.title} has been featured on #{@topical_event.name}"
                       end
      redirect_to polymorphic_path([:admin, @topical_event, :classification_featurings])
    else
      render :new
    end
  end

  def order
    params[:ordering].each do |classification_featuring_id, ordering|
      @topical_event.classification_featurings.find(classification_featuring_id).update_column(:ordering, ordering)
    end
    redirect_to polymorphic_path([:admin, @topical_event, :classification_featurings]), notice: "Featured items re-ordered"
  end

  def destroy
    @classification_featuring = @topical_event.classification_featurings.find(params[:id])

    if featuring_a_document?
      edition = @classification_featuring.edition
      @classification_featuring.destroy!
      flash[:notice] = "#{edition.title} has been unfeatured from #{@topical_event.name}"
    else
      offsite_link = @classification_featuring.offsite_link
      @classification_featuring.destroy!
      flash[:notice] = "#{offsite_link.title} has been unfeatured from #{@topical_event.name}"
    end
    redirect_to polymorphic_path([:admin, @topical_event, :classification_featurings])
  end

  helper_method :featuring_a_document?
  def featuring_a_document?
    @classification_featuring.edition.present?
  end

private

  def load_classification
    @topical_event = Classification.find(params[:topical_event_id] || params[:topic_id])
  end

  def editions_to_show
    if filter_values_set?
      @filter.editions
    else
      @topical_event.editions.published
                              .with_translations
                              .order("editions.created_at DESC")
                              .page(params[:page])
    end
  end

  def filter_values_set?
    params.slice(:page, :type, :author, :organisation, :title).permit!.to_h.any?
  end

  def classification_featuring_params
    params.require(:classification_featuring).permit(
      :alt_text,
      :edition_id,
      :offsite_link_id,
      image_attributes: %i[file file_cache],
    )
  end
end
