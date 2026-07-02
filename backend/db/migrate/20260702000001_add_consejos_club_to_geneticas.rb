class AddConsejosClubToGeneticas < ActiveRecord::Migration[7.2]
  # Consejos del club de cara al paciente (guardado, manipulación, recomendaciones).
  # Público — se muestra en la card de la dispensa. Distinto de `descripcion`, que
  # el admin puede usar como nota general/interna.
  def change
    add_column :geneticas, :consejos_club, :text
  end
end
