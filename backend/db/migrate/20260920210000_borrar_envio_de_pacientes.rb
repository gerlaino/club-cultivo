# Las columnas `envio_*` de `pacientes` eran «la dirección de entrega distinta del domicilio»
# hasta el 17-sep-2026, cuando pasaron a `DireccionPaciente` (varias por paciente, una por
# defecto). Desde entonces nadie las lee ni las escribe (`Paciente#direccion('envio')` va a
# la guardada por defecto; el alta manda los `envio_*` como params y los guarda ahí). Pedido
# explícito de Germán (20-sep-2026). La `dispensaciones.envio_*` NO: ésas son la foto de a
# dónde se mandó cada paquete y siguen vivas.
class BorrarEnvioDePacientes < ActiveRecord::Migration[7.2]
  COLUMNAS = %i[envio_calle envio_altura envio_piso envio_depto envio_barrio envio_ciudad].freeze

  def up
    COLUMNAS.each { |c| remove_column :pacientes, c if column_exists?(:pacientes, c) }
  end

  def down
    COLUMNAS.each { |c| add_column :pacientes, c, :string unless column_exists?(:pacientes, c) }
  end
end
