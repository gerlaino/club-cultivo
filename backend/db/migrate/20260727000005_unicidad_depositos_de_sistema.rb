# Un solo depósito de sistema por (club, sede, clave). La unicidad era SOLO validación de modelo,
# que no protege de una race: la siembra corre desde un before_action y dos requests simultáneos
# del mismo club creaban dos "General"/"Cultivo" para la misma sede (en prod se ven duplicados con
# 1-2 ms de diferencia en created_at). Ahora lo garantiza la tabla.
#
# La migración deduplica ANTES de crear el índice, o no podría crearlo. Lo hace con SQL propio a
# propósito: una migración no debe depender de los modelos de la app (cambian con el tiempo). La
# misma limpieza, para correr a mano, está en `rake depositos:deduplicar`.
#
# COALESCE(sede_id, 0): en un índice único los NULL son distintos entre sí, así que sin esto dos
# depósitos legacy club-wide (sede_id NULL) con la misma clave seguirían pudiendo duplicarse.
# Legacy (sede NULL) y por-sede conviven igual: son claves distintas, que es lo que necesita la
# sede-ificación de Finanzas::SembrarDepositos mientras migra.
class UnicidadDepositosDeSistema < ActiveRecord::Migration[7.2]
  INDEX_NAME = 'index_depositos_sistema_unico'.freeze

  def up
    deduplicar!

    add_index :depositos, 'club_id, COALESCE(sede_id, 0), clave_sistema',
              unique: true, name: INDEX_NAME,
              where: 'clave_sistema IS NOT NULL AND deleted_at IS NULL'
  end

  def down
    remove_index :depositos, name: INDEX_NAME
  end

  private

  # Se queda con el id más bajo de cada grupo (el que referencian los datos más viejos), le mueve
  # los insumos y los productos del bar, y retira el resto (soft-delete: recuperable).
  def deduplicar!
    execute <<~SQL.squish
      WITH ranked AS (
        SELECT id,
               MIN(id) OVER (PARTITION BY club_id, COALESCE(sede_id, 0), clave_sistema) AS keeper
        FROM depositos
        WHERE clave_sistema IS NOT NULL AND deleted_at IS NULL
      )
      UPDATE insumos i SET deposito_id = r.keeper
      FROM ranked r WHERE i.deposito_id = r.id AND r.id <> r.keeper
    SQL

    execute <<~SQL.squish
      WITH ranked AS (
        SELECT id,
               MIN(id) OVER (PARTITION BY club_id, COALESCE(sede_id, 0), clave_sistema) AS keeper
        FROM depositos
        WHERE clave_sistema IS NOT NULL AND deleted_at IS NULL
      )
      UPDATE bar_productos p SET deposito_id = r.keeper
      FROM ranked r WHERE p.deposito_id = r.id AND r.id <> r.keeper
    SQL

    execute <<~SQL.squish
      WITH ranked AS (
        SELECT id,
               MIN(id) OVER (PARTITION BY club_id, COALESCE(sede_id, 0), clave_sistema) AS keeper
        FROM depositos
        WHERE clave_sistema IS NOT NULL AND deleted_at IS NULL
      )
      UPDATE depositos d SET deleted_at = NOW(), updated_at = NOW()
      FROM ranked r WHERE d.id = r.id AND r.id <> r.keeper
    SQL
  end
end
