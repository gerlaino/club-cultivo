class AddFeaturesToClubs < ActiveRecord::Migration[7.0]
  def up
    add_column :clubs, :features, :jsonb, default: {}, null: false
    add_index  :clubs, :features, using: :gin

    # Migrar ia_habilitada → features["ia_analisis"] + features["ia_voz"]
    Club.reset_column_information
    Club.find_each do |club|
      club.update_column(:features, {
        'ia_analisis' => club.ia_habilitada,
        'ia_voz'      => club.ia_habilitada,
      })
    end

    remove_column :clubs, :ia_habilitada
  end

  def down
    add_column :clubs, :ia_habilitada, :boolean, default: false, null: false

    Club.reset_column_information
    Club.find_each do |club|
      club.update_column(:ia_habilitada, club.features['ia_analisis'] || false)
    end

    remove_index  :clubs, :features
    remove_column :clubs, :features
  end
end
