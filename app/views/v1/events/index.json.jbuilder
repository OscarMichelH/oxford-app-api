json.events @events do |event|
  json.id event.id
  json.category event.category
  json.title event.title
  json.description event.description
  json.publication_date event.publication_date
  json.role event.role
  json.campus event.campus&.split(',')
  json.grade event.grade&.split(',')
  json.group event.group&.split(',')
  json.updated_at event.updated_at
  json.total event.total
  json.assist event.assist
  json.view event.view
  json.not_view event.not_view
  json.total_kids event.total_kids
  json.parents event.notifications do |notifcation|
    json.email notifcation.user.email
    json.assist notifcation.assist
    json.seen notifcation.seen
    json.total_kids notifcation.user.kids.count
    json.kids notifcation.user.kids
  end
end

json.events_found @events.count