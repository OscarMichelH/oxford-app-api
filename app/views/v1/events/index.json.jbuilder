json.events @events.includes(:notifications).each do |event|
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
  json.total_pages (event.notifications.count / 20).ceil
  json.current_page @page
  json.parents event.notifications.select(:assist, :seen, :user_id).limit(20).offset((@page-1) * 20).each do |notification|
    json.email notification.user.email
    json.assist notification.assist
    json.seen notification.seen
    json.total_kids notification.user.kids.count
    json.kids notification.user.kids
  end
end

json.events_found @events.count