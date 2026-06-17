class AddDomicilioEstructurado < ActiveRecord::Migration[7.2]
  def change
    # Domicilio registrado del paciente (reutilizable como dirección de entrega por defecto)
    change_table :pacientes, bulk: true do |t|
      t.string :domicilio_calle
      t.string :domicilio_altura
      t.string :domicilio_piso
      t.string :domicilio_depto
      t.string :domicilio_barrio
      t.string :domicilio_ciudad
    end

    # Dirección de entrega de la dispensa (snapshot: a dónde fue ESTE envío).
    # direccion_envio (texto compuesto) se mantiene para mostrar y para Maps.
    change_table :dispensaciones, bulk: true do |t|
      t.string :envio_calle
      t.string :envio_altura
      t.string :envio_piso
      t.string :envio_depto
      t.string :envio_barrio
      t.string :envio_ciudad
    end
  end
end
