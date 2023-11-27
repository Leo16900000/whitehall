class Admin::TakePartPagesController < Admin::BaseController
  before_action :enforce_permissions!
  before_action :clean_take_part_page_params, only: %i[create update]

  def enforce_permissions!
    enforce_permission!(:administer, :get_involved_section)
  end

  def index
    @take_part_pages = TakePartPage.in_order
  end

  def new
    @take_part_page = TakePartPage.new
    @take_part_page.build_image if @take_part_page.image.blank?
  end

  def create
    @take_part_page = TakePartPage.new(take_part_page_params)
    if @take_part_page.save
      redirect_to [:admin, TakePartPage], notice: %(Take part page "#{@take_part_page.title}" created!)
    else
      @take_part_page.build_image if @take_part_page.image.blank?
      render :new
    end
  end

  def edit
    @take_part_page = TakePartPage.friendly.find(params[:id])
    @take_part_page.build_image if @take_part_page.image.blank?
  end

  def update
    @take_part_page = TakePartPage.friendly.find(params[:id])
    if @take_part_page.update(take_part_page_params)
      redirect_to [:admin, TakePartPage], notice: %(Take part page "#{@take_part_page.title}" updated!)
    else
      render :edit
    end
  end

  def confirm_destroy
    @take_part_page = TakePartPage.friendly.find(params[:id])
  end

  def destroy
    @take_part_page = TakePartPage.friendly.find(params[:id])
    @take_part_page.destroy!
    redirect_to [:admin, TakePartPage], notice: %(Take part page "#{@take_part_page.title}" deleted!)
  end

  def update_order
    @take_part_pages = TakePartPage.in_order
  end

  def reorder
    new_ordering = (params.permit!.to_h[:ordering] || []).sort_by { |_id, ordering| ordering.to_i }.map(&:first)
    TakePartPage.reorder!(new_ordering)
    redirect_to admin_take_part_pages_path, notice: "Take part pages reordered!"
  end

private

  def take_part_page_params
    @take_part_page_params ||= params.require(:take_part_page).permit(
      :title,
      :summary,
      :body,
      :image_alt_text,
      image_attributes: %i[file file_cache id],
    )
  end

  def clean_take_part_page_params
    if take_part_page_params.dig(:image_attributes, :file_cache).present? && take_part_page_params.dig(:image_attributes, :file).present?
      take_part_page_params[:image_attributes].delete(:file_cache)
    end
  end
end
