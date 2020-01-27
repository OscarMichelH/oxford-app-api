class AddEventIdToNotifications < ActiveRecord::Migration[5.2]
  def change
    remove_column :notifications, :event_id
    add_reference :notifications, :event, foreign_key: true
  end
end
