class AddExtralinksToNotices < ActiveRecord::Migration[7.1]
  def change
    add_column :notices, :extralinks, :string
  end
end
