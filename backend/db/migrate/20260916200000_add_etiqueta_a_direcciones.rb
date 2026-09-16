# Un nombre para la dirección de envío («Trabajo», «Casa de la madre»). El socio de Germán lo
# necesitó antes de que existiera: escribió "TRABAJO" en el campo Depto, que era el único lugar
# donde entraba, y Maps dejó de encontrar la dirección. En la dispensa queda como snapshot para
# que el repartidor vea «Trabajo · Directorio 1602» en el paquete y en la etiqueta impresa.
# El domicilio no lleva etiqueta: es «Domicilio REPROCANN» siempre.
class AddEtiquetaADirecciones < ActiveRecord::Migration[7.2]
  def change
    add_column :pacientes,      :envio_etiqueta,     :string
    add_column :dispensaciones, :direccion_etiqueta, :string
  end
end
