# Marca los clubes que existen para MOSTRAR la app, no para operar: el club modelo que se le enseña
# a un prospecto y las copias de prueba.
#
# Sin esta marca, un club demo con 200 dispensaciones inventadas entra en las métricas globales del
# super admin como un club más. Y de cara al roadmap (Fase 5: benchmarking y data agregada del
# sector) es peor: el día que se comparen rendimientos entre clubes, los números que nunca existieron
# van a estar adentro del promedio.
class AgregarDemoAClubs < ActiveRecord::Migration[7.2]
  def change
    add_column :clubs, :demo, :boolean, default: false, null: false
    add_index  :clubs, :demo, where: 'demo = true'
  end
end
