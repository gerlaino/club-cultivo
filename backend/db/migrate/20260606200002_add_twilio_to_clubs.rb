class AddTwilioToClubs < ActiveRecord::Migration[7.2]
  def change
    add_column :clubs, :twilio_account_sid,        :string
    add_column :clubs, :twilio_auth_token_enc,      :string
    add_column :clubs, :twilio_whatsapp_from,       :string
  end
end
