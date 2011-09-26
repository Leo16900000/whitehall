class Edition < ActiveRecord::Base
  belongs_to :author, class_name: "User"
  belongs_to :policy

  scope :drafts, where(submitted: false)
  scope :submitted, where(submitted: true, published: false)
  scope :published, where(published: true)

  validates_presence_of :title, :body, :author, :policy

  def publish_as!(user, lock_version = self.lock_version)
    if user == author
      errors.add(:base, "You are not the second set of eyes")
    elsif !user.departmental_editor?
      errors.add(:base, "Only departmental editors can publish policies")
    else
      update_attributes(published: true, lock_version: lock_version)
    end
    errors.empty?
  end
end
