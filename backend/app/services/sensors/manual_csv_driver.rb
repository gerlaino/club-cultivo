module Sensors
  # Parses a CSV file with columns: medido_at, tipo, valor [, unidad]
  # Expected header row, one reading per line.
  class ManualCsvDriver < BaseDriver
    require 'csv'

    def lecturas_desde(csv_content)
      CSV.parse(csv_content.to_s, headers: true, skip_blanks: true).filter_map do |row|
        tipo      = row['tipo']&.strip
        valor_str = row['valor']&.strip
        ts_str    = row['medido_at']&.strip

        next unless tipo.present? && valor_str.present? && ts_str.present?
        next unless AmbienteTipos::TIPOS.include?(tipo)

        medido_at = Time.zone.parse(ts_str) rescue nil
        next unless medido_at

        {
          tipo:      tipo,
          valor:     valor_str.to_f,
          unidad:    AmbienteTipos::TIPOS_CANONICOS[tipo],
          medido_at: medido_at,
        }
      end
    end
  end
end
