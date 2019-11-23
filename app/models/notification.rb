class Notification < ApplicationRecord
  belongs_to :user

  scope :by_event_id, -> (events) { where(event_id: events) }
  scope :by_role, -> (role) { where(role: role) }
  scope :by_categories, -> (categories) { where(category: categories) }
  scope :by_title, -> (title) { where(title: title) }
  scope :by_description, -> (description) { where(description: description) }
  scope :by_publication_date, -> (publication_date) { where(publication_date: publication_date) }
  scope :by_campuses, -> (campuses) { where(campus: campuses) }
  scope :by_grades, -> (grades) { where(grade: grades) }
  scope :by_groups, -> (groups) { where(group: groups) }
  scope :by_family_keys, -> (family_keys) { where(family_key: family_keys) }
  scope :by_student_names, -> (student_names) { where(name: student_names) }
  scope :after_date, -> { where("publication_date < ?", Time.now) }
  scope :with_date, (lambda do |start_date, end_date|
    where("publication_date > ? AND publication_date < ?",
          start_date, end_date)
  end)
end
