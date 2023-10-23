class Admin::OrganisationComponent < ViewComponent::Base
  def organisations_list(organisations)
    organisations.map do |organisation|
      link_to organisation.name, organisation.public_path, class: "govuk-link"
    end
  end
end
