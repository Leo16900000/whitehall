class Admin::EditionableWorldwideOrganisationsTranslationsController < Admin::EditionTranslationsController
  include TranslationControllerConcern

  def confirm_destroy
    binding.pry
  end
end
