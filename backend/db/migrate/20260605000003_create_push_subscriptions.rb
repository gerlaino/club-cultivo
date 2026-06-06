class CreatePushSubscriptions < ActiveRecord::Migration[7.0]
  def change
    create_table :push_subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :club, null: false, foreign_key: true
      t.string  :endpoint,    null: false
      t.string  :p256dh_key,  null: false
      t.string  :auth_key,    null: false
      t.string  :device_name
      t.boolean :active,      null: false, default: true
      t.timestamps
    end

    add_index :push_subscriptions, :endpoint, unique: true
  end

  def down
    drop_table :push_subscriptions
  end
end
