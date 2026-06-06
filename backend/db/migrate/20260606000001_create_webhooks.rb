class CreateWebhooks < ActiveRecord::Migration[7.0]
  def change
    create_table :webhooks do |t|
      t.references :club,       null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string  :nombre,    null: false
      t.string  :url,       null: false
      t.string  :secret,    null: false
      t.string  :events,    null: false, default: '[]'
      t.boolean :active,    null: false, default: true
      t.timestamps
    end

    create_table :webhook_deliveries do |t|
      t.references :webhook, null: false, foreign_key: true
      t.string  :event,            null: false
      t.text    :payload_json
      t.string  :status,           null: false, default: 'pending'
      t.integer :http_code
      t.integer :duration_ms
      t.text    :error_message
      t.integer :attempts,         null: false, default: 0
      t.datetime :last_attempted_at
      t.timestamps
    end

    add_index :webhook_deliveries, [:webhook_id, :created_at]
    add_index :webhook_deliveries, :status
  end

  def down
    drop_table :webhook_deliveries
    drop_table :webhooks
  end
end
