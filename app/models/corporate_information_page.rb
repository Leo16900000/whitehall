class CorporateInformationPage < Edition
  include ::Attachable
  include Searchable

  after_commit :republish_owning_organisation_to_publishing_api
  after_commit :republish_about_page_to_publishing_api, unless: :about_page?
  after_save :reindex_organisation_in_search_index, if: :about_page?

  has_one :edition_organisation, foreign_key: :edition_id, dependent: :destroy
  has_one :organisation, -> { includes(:translations) }, through: :edition_organisation, autosave: false
  has_one :edition_worldwide_organisation, foreign_key: :edition_id, inverse_of: :edition, dependent: :destroy
  has_one :legacy_worldwide_organisation, class_name: "LegacyWorldwideOrganisation", through: :edition_worldwide_organisation, autosave: false

  delegate :slug, :display_type_key, to: :corporate_information_page_type
  validate :unique_organisation_and_page_type, on: :create, if: :organisation
  validate :unique_worldwide_organisation_and_page_type, on: :create, if: :legacy_worldwide_organisation

  add_trait do
    def process_associations_before_save(new_edition)
      if @edition.organisation
        new_edition.organisation = @edition.organisation
      elsif @edition.legacy_worldwide_organisation
        new_edition.legacy_worldwide_organisation = @edition.legacy_worldwide_organisation
      end
    end
  end
  delegate :alternative_format_contact_email, :acronym, to: :owning_organisation

  validates :corporate_information_page_type_id, presence: true
  validate :only_one_organisation_or_worldwide_organisation

  scope :with_organisation_govuk_status, ->(status) { joins(:organisation).where(organisations: { govuk_status: status }) }
  scope :accessible_documents_policy, -> { where(corporate_information_page_type_id: CorporateInformationPageType::AccessibleDocumentsPolicy.id) }

  def republish_owning_organisation_to_publishing_api
    return if owning_organisation.blank?

    edition_states = %w[draft submitted]
    if edition_states.include?(state) && legacy_worldwide_organisation.present?
      presenter = PublishingApi::WorldwideOrganisationPresenter.new(owning_organisation, state:)
      return Services.publishing_api.put_content(presenter.content_id, presenter.content)
    end

    Whitehall::PublishingApi.republish_async(owning_organisation)
  end

  def republish_about_page_to_publishing_api
    about_us = if state == "draft"
                 owning_organisation&.about_us_for(state: "draft")
               else
                 owning_organisation&.about_us
               end
    return unless about_us

    PublishingApiDocumentRepublishingWorker.perform_async_in_queue(
      "bulk_republishing",
      about_us.document_id,
      true,
    )
  end

  def reindex_organisation_in_search_index
    owning_organisation.update_in_search_index
  end

  def body_required?
    !about_page?
  end

  def search_title
    title_prefix_organisation_name
  end

  def search_index
    super.merge("organisations" => [owning_organisation.slug])
  end

  def self.search_only
    live_govuk_status = super.with_organisation_govuk_status("live")

    accessible_other_govuk_status = super
      .accessible_documents_policy
      .with_organisation_govuk_status(%w[joining exempt transitioning])

    accessible_devolved_govuk_status = super
      .accessible_documents_policy
      .with_organisation_govuk_status("closed")
      .where(organisations: { govuk_closed_status: "devolved" })

    live_govuk_status
      .or(accessible_other_govuk_status)
      .or(accessible_devolved_govuk_status)
  end

  def title_required?
    false
  end

  def only_one_organisation_or_worldwide_organisation
    if organisation && legacy_worldwide_organisation
      errors.add(:base, "Only one organisation or worldwide organisation allowed")
    end
  end

  def skip_organisation_validation?
    true
  end

  def translatable?
    !non_english_edition?
  end

  def owning_organisation
    organisation || legacy_worldwide_organisation
  end

  def organisations
    [owning_organisation]
  end

  def sorted_organisations
    organisations
  end

  def api_presenter_redirect_to
    raise "only worldwide about pages should redirect" unless about_page? && legacy_worldwide_organisation.present?

    legacy_worldwide_organisation.public_path(locale: I18n.locale)
  end

  def self.for_slug(slug)
    if (type = CorporateInformationPageType.find(slug))
      find_by(corporate_information_page_type_id: type.id)
    end
  end

  def self.for_slug!(slug)
    if (type = CorporateInformationPageType.find(slug))
      find_by!(corporate_information_page_type_id: type.id)
    end
  end

  def corporate_information_page_type
    CorporateInformationPageType.find_by_id(corporate_information_page_type_id)
  end

  def corporate_information_page_type=(type)
    self.corporate_information_page_type_id = type && type.id
  end

  def title_prefix_organisation_name
    [owning_organisation.name, title].join(" \u2013 ")
  end

  def title(_locale = :en)
    corporate_information_page_type.title(owning_organisation)
  end

  def title_lang
    corporate_information_page_type.title_lang(owning_organisation)
  end

  def self.by_menu_heading(menu_heading)
    type_ids = CorporateInformationPageType.by_menu_heading(menu_heading).map(&:id)
    where(corporate_information_page_type_id: type_ids)
  end

  def summary_required?
    false
  end

  def about_page?
    corporate_information_page_type.try(:slug) == "about"
  end

  def rendering_app
    Whitehall::RenderingApp::GOVERNMENT_FRONTEND
  end

  def previously_published
    false
  end

  def alternative_format_provider
    owning_organisation
  end

  def alternative_format_provider_required?
    attachments.any? { |a| a.is_a?(FileAttachment) }
  end

  def base_path
    return if owning_organisation.blank?

    if about_page?
      "#{owning_organisation.base_path}/about"
    else
      "#{owning_organisation.base_path}/about/#{slug}"
    end
  end

  def publishing_api_presenter
    if legacy_worldwide_organisation.present? && about_page?
      PublishingApi::RedirectPresenter
    elsif legacy_worldwide_organisation.present?
      PublishingApi::WorldwideCorporateInformationPagePresenter
    else
      PublishingApi::CorporateInformationPagePresenter
    end
  end

private

  def string_for_slug
    nil
  end

  def unique_organisation_and_page_type
    duplicate_scope = CorporateInformationPage
      .joins(:edition_organisation)
      .where("edition_organisations.organisation_id = ?", organisation.id)
      .where(corporate_information_page_type_id:)
      .where("state not like 'superseded'")
    if document_id
      duplicate_scope = duplicate_scope.where("document_id <> ?", document_id)
    end
    if duplicate_scope.exists?
      errors.add(:base, "Another '#{display_type_key.humanize}' page was already published for this organisation")
    end
  end

  def unique_worldwide_organisation_and_page_type
    duplicate_scope = CorporateInformationPage
      .joins(:edition_worldwide_organisation)
      .where("edition_worldwide_organisations.worldwide_organisation_id = ?", legacy_worldwide_organisation.id)
      .where(corporate_information_page_type_id:)
      .where("state not like 'superseded'")
    if document_id
      duplicate_scope = duplicate_scope.where("document_id <> ?", document_id)
    end
    if duplicate_scope.exists?
      errors.add(:base, "Another '#{display_type_key.humanize}' page was already published for this worldwide organisation")
    end
  end
end
