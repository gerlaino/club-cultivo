class BackfillCobros < ActiveRecord::Migration[7.2]
  # Espeja en `cobros` lo que ya está asentado en las dispensaciones existentes, para
  # que todo quede en un solo camino (sin lógica dual viejo/nuevo). NO re-ejecuta
  # contabilidad ni toca cuenta corriente: los movimientos ya existen. Solo crea los
  # registros de cobro a partir de aporte_socio_ars / monto_credito_ars / medio_pago.
  #   - credito (monto_credito_ars)  → cobro cuenta_corriente (pagado: false)
  #   - resto (efectivo/transferencia) → cobro pagado con el medio original
  #   - credito_gramos → se omite (es otra unidad, no pesos)
  def up
    say_with_time 'Backfill de cobros para dispensaciones existentes' do
      count = 0
      Dispensacion.includes(:cobros, stock: { sede: :club }).find_each do |d|
        next if d.cobros.any?
        next if d.medio_pago == 'credito_gramos'
        total = d.aporte_socio_ars.to_d
        next if total <= 0

        club_id    = d.sede&.club_id || d.stock&.sede&.club_id
        created_by = d.user_id
        next unless club_id && created_by

        credito = d.monto_credito_ars.to_d.clamp(0, total)
        pagado  = total - credito
        medio_pagado = %w[efectivo transferencia].include?(d.medio_pago) ? d.medio_pago : 'efectivo'

        if credito > 0
          Cobro.create!(dispensacion_id: d.id, club_id: club_id, created_by_id: created_by,
                        medio: 'cuenta_corriente', monto_ars: credito, pagado: false,
                        contexto: 'creacion', notas: 'backfill')
          count += 1
        end
        if pagado > 0
          Cobro.create!(dispensacion_id: d.id, club_id: club_id, created_by_id: created_by,
                        medio: medio_pagado, monto_ars: pagado, pagado: true,
                        contexto: 'creacion', notas: 'backfill')
          count += 1
        end
      end
      count
    end
  end

  def down
    Cobro.where(notas: 'backfill').delete_all
  end
end
