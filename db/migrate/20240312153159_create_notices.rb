class CreateNotices < ActiveRecord::Migration[7.1]
  def change
    create_table :notices do |t|
      t.integer :from
      t.string :title
      t.string :source
      t.date :date
      t.date :duedate

      t.timestamps
    end
  end
end
