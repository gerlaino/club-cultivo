class MigrateManicuraPendienteToPesajeFlow < ActiveRecord::Migration[7.2]
  # Unificación del flujo de manicura: el estado legacy `manicura_pendiente` deja de
  # usarse. Cada lote en vuelo se reconvierte al flujo único de PesajeManicura:
  #   - se genera un PesajeManicura en estado `enviado` (cae en la cola de confirmación
  #     del admin en /admin/pesajes-manicura),
  #   - se repuntan las pesadas por planta al nuevo pesaje (para el conteo de finalización),
  #   - el lote vuelve a `en_manicura`.
  # Idempotente: si el lote ya tiene un pesaje enviado/confirmado, se saltea.
  def up
    say_with_time 'Migrando lotes manicura_pendiente al flujo de PesajeManicura' do
      migrados = 0
      Lote.where(estado: 'manicura_pendiente').find_each do |lote|
        if lote.pesajes_manicura.where(estado: %w[enviado confirmado]).exists?
          lote.update_columns(estado: 'en_manicura') # ya tiene flujo nuevo, solo destrabar el estado
          next
        end

        pesada = lote.pesadas.where(manicurado: true).order(id: :desc).first

        peso = pesada&.peso_seco_g.to_d
        peso = pesada.pesadas_plantas.sum(:peso_seco_g).to_d if pesada && peso <= 0

        count = pesada&.pesadas_plantas&.count.to_i
        count = pesada.plantas_manicuradas.to_i if count.zero? && pesada

        manicurador_id = lote.manicurador_id || pesada&.registrado_por_id

        if peso <= 0 || manicurador_id.nil?
          say "  ⚠ Lote #{lote.id} (#{lote.codigo}) sin peso/manicurador resoluble — se mueve a en_manicura sin pesaje", true
          lote.update_columns(estado: 'en_manicura', manicurador_id: manicurador_id || lote.manicurador_id)
          next
        end

        pesaje = lote.pesajes_manicura.create!(
          club_id:        lote.club_id,
          manicurador_id: manicurador_id,
          fecha_pesaje:   pesada&.registrado_at&.to_date || Date.current,
          estado:         'enviado',
          enviado_at:     Time.current,
          peso_total_g:   peso,
          plantas_count:  count.positive? ? count : nil,
          notas:          '[Migrado del flujo anterior]',
        )

        pesada.pesadas_plantas.update_all(pesaje_manicura_id: pesaje.id) if pesada

        lote.update_columns(estado: 'en_manicura', manicurador_id: manicurador_id)
        migrados += 1
      end
      migrados
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
