class Document < ActiveRecord::Base
  include Document::Identifiable
  include Document::AccessControl
  include Document::Workflow
  include Document::Organisations
  include Document::Publishing

  belongs_to :author, class_name: "User"

  validates_presence_of :title, :body, :author

  def can_be_associated_with_topics?
    false
  end

  def can_be_associated_with_ministers?
    false
  end

  def can_be_fact_checked?
    false
  end

  def can_be_related_to_other_documents?
    false
  end

  def can_apply_to_subset_of_nations?
    false
  end

  def allows_attachments?
    false
  end

  def allows_supporting_documents?
    false
  end

  def has_supporting_documents?
    false
  end

  def submit_as(user)
    update_attribute(:submitted, true)
  end

  def create_draft(user)
    draft_attributes = {
      state: "draft",
      author: user,
      submitted: false,
      organisations: organisations
    }
    draft_attributes[:topics] = topics if can_be_associated_with_topics?
    draft_attributes[:ministerial_roles] = ministerial_roles if can_be_associated_with_ministers?
    draft_attributes[:documents_related_with] = documents_related_with if can_be_related_to_other_documents?
    draft_attributes[:documents_related_to] = documents_related_to if can_be_related_to_other_documents?
    draft_attributes[:inapplicable_nations] = inapplicable_nations if can_apply_to_subset_of_nations?
    new_draft = self.class.create(attributes.merge(draft_attributes))
    if new_draft.valid?
      if allows_supporting_documents?
        supporting_documents.each do |sd|
          new_draft.supporting_documents.create(sd.attributes.except("document_id"))
        end
      end
      if allows_attachments?
        attachments.each do |a|
          new_draft.document_attachments.create(attachment_id: a.id)
        end
      end
    end
    new_draft
  end

  def title_with_state
    state_string = (draft? && submitted?) ? 'submitted' : state
    "#{title} (#{state_string})"
  end

  class << self
    def by_type(type)
      where(Document.arel_table[:type].matches("%#{type}%"))
    end

    def related_to(document)
      where(id: document.related_documents.collect(&:id))
    end
  end
end
