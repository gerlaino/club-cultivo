# Renombra el área del sistema "Administración" → "General" (nombre visible más claro).
# `tipo` sigue siendo 'administracion' (clave interna estable); solo cambia la etiqueta.
# Solo toca las que conservan el nombre por defecto (no pisa nombres personalizados por el club).
# SQL directo para no depender del tenant (unidades_negocio es acts_as_tenant).
class RenombrarAdministracionAGeneral < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      UPDATE unidades_negocio SET nombre = 'General'
      WHERE tipo = 'administracion' AND nombre = 'Administración'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE unidades_negocio SET nombre = 'Administración'
      WHERE tipo = 'administracion' AND nombre = 'General'
    SQL
  end
end
