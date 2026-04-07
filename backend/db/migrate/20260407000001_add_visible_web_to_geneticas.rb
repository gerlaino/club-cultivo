class AddVisibleWebToGeneticas < ActiveRecord::Migration[7.2]
  def change
    add_column :geneticas, :visible_web, :boolean, default: false, null: false
    add_column :clubs, :web_activa, :boolean, default: false, null: false
    add_column :clubs, :descripcion_web, :text
    add_column :clubs, :instagram_url, :string
    add_column :clubs, :facebook_url, :string
    add_column :clubs, :whatsapp, :string
    add_column :clubs, :horarios_atencion, :text
  end
end