# Qué se le APLICÓ a un lote, y no sólo qué se le vio.
#
# `plagas_observadas` guarda lo que se detectó, pero no había dónde anotar con qué se trató. Hoy
# eso termina suelto en `notas_fertilizacion` u `observaciones`, mezclado con los nutrientes — y
# para cannabis MEDICINAL es justamente el dato más sensible que existe: alguien inmunodeprimido
# tiene derecho a saber si a lo que consume le aplicaron un fungicida, cuál, y cuándo.
#
# Es la diferencia entre un registro de cultivo y un registro sanitario.
#
# `carencia_dias` es el plazo entre la aplicación y la cosecha durante el cual no debería
# cosecharse. Va acá y no se calcula: depende del producto y lo sabe quien lo aplica.
#
# Aparte se DROPEA `analisis_ia`: el análisis de lote se eliminó (lo reemplazó el chatbot) y sus
# datos ya se limpiaron con `rake analisis_ia:limpiar`. La tabla quedaba sin modelo y sin uso.
class RegistroFitosanitarioYBajaAnalisisIa < ActiveRecord::Migration[7.2]
  def up
    add_column :registros_ambientales, :fitosanitario,        :string   # qué producto se aplicó
    add_column :registros_ambientales, :fitosanitario_motivo, :string   # contra qué
    add_column :registros_ambientales, :carencia_dias,        :integer  # días hasta poder cosechar

    drop_table :analisis_ia, if_exists: true
  end

  # Irreversible a propósito en la parte del drop: recrear la tabla vacía no devolvería los datos
  # y daría la falsa impresión de que se puede volver atrás.
  def down
    remove_column :registros_ambientales, :fitosanitario
    remove_column :registros_ambientales, :fitosanitario_motivo
    remove_column :registros_ambientales, :carencia_dias

    raise ActiveRecord::IrreversibleMigration, 'analisis_ia se dropeó con sus datos ya limpiados'
  end
end
