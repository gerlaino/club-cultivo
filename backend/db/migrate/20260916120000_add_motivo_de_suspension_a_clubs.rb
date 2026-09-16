# «Suspendida · Reactivar» era un aviso que no se apagaba: la suspendí yo porque no pagó, el
# pendiente es COBRAR, no reactivar, y sin motivo ni fecha quedaba en rojo para siempre. Con el
# motivo, la cola del panel muestra la acción que corresponde; con «archivar», una organización
# que se fue sale de la cola sin borrarse (eliminar libera sus identificadores; archivar no).
class AddMotivoDeSuspensionAClubs < ActiveRecord::Migration[7.2]
  def change
    add_column :clubs, :suspension_motivo, :string
    add_column :clubs, :suspendida_at,     :datetime
    add_column :clubs, :archivada_at,      :datetime
  end
end
