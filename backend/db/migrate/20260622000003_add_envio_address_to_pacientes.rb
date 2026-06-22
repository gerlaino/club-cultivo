class AddEnvioAddressToPacientes < ActiveRecord::Migration[7.2]
  # Dirección de entrega del paciente (opcional). El domicilio (domicilio_*) sigue siendo
  # la dirección del paciente; estos campos son la dirección de entrega alternativa.
  # Si están vacíos, la entrega usa el domicilio por defecto.
  def change
    add_column :pacientes, :envio_calle,  :string
    add_column :pacientes, :envio_altura, :string
    add_column :pacientes, :envio_piso,   :string
    add_column :pacientes, :envio_depto,  :string
    add_column :pacientes, :envio_barrio, :string
    add_column :pacientes, :envio_ciudad, :string
  end
end
