json.events @events.zip(@parents) do |event, parent|
  json.id event.id
  json.category event.category
  json.title event.title
  json.description event.description
  json.publication_date event.publication_date
  json.role event.role
  json.campus event.campus&.split(',')
  json.grade event.grade
  json.group event.group
  json.updated_at event.updated_at
  json.total event.total
  json.assist event.assist
  json.view event.view
  json.not_view event.not_view
  json.total_kids event.total_kids
  json.parents parent
end

json.events_found @events_found