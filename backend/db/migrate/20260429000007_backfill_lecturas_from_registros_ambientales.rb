class BackfillLecturasFromRegistrosAmbientales < ActiveRecord::Migration[7.2]
  METRIC_MAP = {
    'temperatura'          => '°C',
    'humedad'              => '%',
    'vpd'                  => 'kPa',
    'co2'                  => 'ppm',
    'ph'                   => 'pH',
    'ec'                   => 'mS/cm',
    'temperatura_sustrato' => '°C',
    'ph_runoff'            => 'pH',
    'ec_runoff'            => 'mS/cm',
    'ppfd'                 => 'µmol/m²s',
  }.freeze

  def up
    return unless table_exists?(:lecturas_ambientales)

    execute(<<~SQL)
      INSERT INTO lecturas_ambientales
        (club_id, sala_id, lote_id, tipo, valor, unidad, medido_at, fuente,
         origen_record_type, origen_record_id, created_at, updated_at)
      SELECT
        ra.club_id,
        l.sala_id,
        ra.lote_id,
        m.tipo,
        m.valor::decimal,
        m.unidad,
        ra.registrado_en,
        'backfill',
        'RegistroAmbiental',
        ra.id,
        NOW(),
        NOW()
      FROM registros_ambientales ra
      JOIN lotes l ON l.id = ra.lote_id
      CROSS JOIN LATERAL (VALUES
        ('temperatura',          ra.temperatura::text,          '°C'),
        ('humedad',              ra.humedad::text,              '%'),
        ('vpd',                  ra.vpd::text,                  'kPa'),
        ('co2',                  ra.co2::text,                  'ppm'),
        ('ph',                   ra.ph::text,                   'pH'),
        ('ec',                   ra.ec::text,                   'mS/cm'),
        ('temperatura_sustrato', ra.temperatura_sustrato::text, '°C'),
        ('ph_runoff',            ra.ph_runoff::text,            'pH'),
        ('ec_runoff',            ra.ec_runoff::text,            'mS/cm'),
        ('ppfd',                 ra.ppfd::text,                 'µmol/m²s')
      ) AS m(tipo, valor, unidad)
      WHERE m.valor IS NOT NULL AND m.valor != 'null'
      ON CONFLICT DO NOTHING
    SQL
  end

  def down
    execute "DELETE FROM lecturas_ambientales WHERE fuente = 'backfill'"
  end
end
