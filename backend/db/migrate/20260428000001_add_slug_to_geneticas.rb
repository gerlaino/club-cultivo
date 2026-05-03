class AddSlugToGeneticas < ActiveRecord::Migration[7.2]
  def up
    add_column :geneticas, :slug, :string

    # Backfill: kebab-case desde nombre, sufijo numérico si colisión
    execute <<~SQL
      UPDATE geneticas
      SET slug = subq.final_slug
      FROM (
        WITH base AS (
          SELECT id,
                 lower(regexp_replace(
                   regexp_replace(
                     regexp_replace(nombre, '[áàäâã]', 'a', 'gi'),
                   '[éèëê]', 'e', 'gi'),
                 '[^a-z0-9]+', '-', 'gi')
                 ) AS base_slug
          FROM geneticas
        ),
        ranked AS (
          SELECT id, base_slug,
                 row_number() OVER (PARTITION BY base_slug ORDER BY id) AS rn
          FROM base
        )
        SELECT id,
               CASE WHEN rn = 1 THEN base_slug
                    ELSE base_slug || '-' || rn
               END AS final_slug
        FROM ranked
      ) subq
      WHERE geneticas.id = subq.id
    SQL

    add_index :geneticas, :slug, unique: true
    change_column_null :geneticas, :slug, false
  end

  def down
    remove_column :geneticas, :slug
  end
end
