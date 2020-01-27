class CreateEvents < ActiveRecord::Migration[5.2]
  def change
    create_table :events do |t|
      t.text :category
      t.string :title
      t.text :description
      t.datetime :publication_date
      t.string :role
      t.string :campus
      t.string :grade
      t.string :group
      t.integer :total
      t.integer :assist
      t.integer :view
      t.integer :not_view
      t.integer :total_kids
      t.string :created_by

      t.timestamps
    end
  end
end
