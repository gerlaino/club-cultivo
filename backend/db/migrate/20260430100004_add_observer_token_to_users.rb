class AddObserverTokenToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :observer_club_id,     :bigint
    add_column :users, :observer_token,        :string
    add_column :users, :observer_expires_at,   :datetime
  end
end
