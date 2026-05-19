class AddSmtpToClubs < ActiveRecord::Migration[7.1]
  def change
    add_column :clubs, :smtp_host,      :string
    add_column :clubs, :smtp_port,      :integer, default: 587
    add_column :clubs, :smtp_user,      :string
    add_column :clubs, :smtp_pass,      :string
    add_column :clubs, :smtp_from,      :string
    add_column :clubs, :smtp_from_name, :string
  end
end
