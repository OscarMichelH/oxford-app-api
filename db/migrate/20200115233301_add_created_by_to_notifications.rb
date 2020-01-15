class AddCreatedByToNotifications < ActiveRecord::Migration[5.2]
  def change
    add_column :notifications, :created_by, :string
  end
end
