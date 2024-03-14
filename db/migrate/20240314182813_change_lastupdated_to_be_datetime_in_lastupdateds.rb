class ChangeLastupdatedToBeDatetimeInLastupdateds < ActiveRecord::Migration[7.1]
  def change
    change_column :lastupdateds, :lastupdated, :datetime
  end
end
