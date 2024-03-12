class CreateLastupdateds < ActiveRecord::Migration[7.1]
  def change
    create_table :lastupdateds do |t|
      t.date :lastupdated

      t.timestamps
    end
  end
end
