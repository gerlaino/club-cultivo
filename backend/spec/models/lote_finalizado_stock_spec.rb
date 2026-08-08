require 'rails_helper'

# 'finalizado' significa UNA cosa: no queda nada de este lote. El informe de trazabilidad lo
# muestra como ciclo cerrado, así que un lote finalizado con 485 g adentro es dato sucio.
#
# La regla vivía sólo en `finalizar_si_stock_agotado!` y cualquier otro código que escribiera
# el estado a mano la salteaba — pasó de verdad: el sembrador de datos demo dejó 16 lotes así.
RSpec.describe Lote, 'finalizado exige que no quede producto' do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:lote)  { create(:lote, club: club, estado: 'curado') }

  def stock_del_lote(cantidad:, estado: 'asignado', forma: 'flor_seca', origen: 'lote')
    s = build(:stock, club: club, sede: sede, lote: lote, origen: origen,
                      forma_producto: forma, cantidad: cantidad, estado: estado)
    if origen == 'derivado_lote'
      # Un derivado declara cuánta flor consumió. `es_split` evita que el modelo vuelva a
      # descontar del stock de origen: acá se arma el escenario a mano.
      s.lote_origen_consumido_g = [cantidad.to_d * 3, 1].max
      s.es_split = true
    end
    # El autor viaja hasta el callback que cierra el lote (`lote_eventos.user_id` es NOT NULL).
    s.usuario_movimiento = admin
    s.save!
    s
  end

  describe 'la validación' do
    it 'rechaza pasar a finalizado con flor sin dispensar' do
      stock_del_lote(cantidad: 485.1)

      lote.estado = 'finalizado'

      expect(lote).not_to be_valid
      expect(lote.errors[:estado].join).to match(/485\.1/)
    end

    it 'deja finalizar cuando todo el stock está agotado' do
      stock_del_lote(cantidad: 0, estado: 'agotado')

      lote.estado = 'finalizado'

      expect(lote).to be_valid
    end

    # Un lote cuyas plantas se descartaron nunca generó stock: cerrarlo es correcto.
    it 'deja finalizar un lote que nunca tuvo stock' do
      lote.estado = 'finalizado'

      expect(lote).to be_valid
    end

    # No se puede dejar el registro imposible de guardar: hay que poder corregirlo.
    it 'no bloquea guardar un lote que YA estaba mal, si no se toca el estado' do
      stock_del_lote(cantidad: 100)
      lote.update_columns(estado: 'finalizado')

      lote.reload.rendimiento_real_g = 123.4

      expect(lote).to be_valid
    end
  end

  # Lo que Germán pidió verificar: el lote cierra cuando se acaba el stock Y sus derivados.
  describe 'los derivados cuentan' do
    # Orden real: primero se elabora el hash (consumiendo flor) y después se termina la flor.
    it 'no finaliza si la flor se agotó pero queda hash de ese lote' do
      stock_del_lote(cantidad: 40, forma: 'hash', origen: 'derivado_lote')
      stock_del_lote(cantidad: 0, estado: 'agotado')

      lote.estado = 'finalizado'
      expect(lote).not_to be_valid

      lote.reload
      lote.finalizar_si_stock_agotado!(usuario: admin)
      expect(lote.reload.estado).to eq('curado')
    end

    it 'finaliza cuando se agotan la flor y el derivado' do
      derivado = stock_del_lote(cantidad: 5, forma: 'hash', origen: 'derivado_lote')
      stock_del_lote(cantidad: 0, estado: 'agotado')

      lote.finalizar_si_stock_agotado!(usuario: admin)
      expect(lote.reload.estado).to eq('curado')

      derivado.update_columns(cantidad: 0, estado: 'agotado')

      lote.finalizar_si_stock_agotado!(usuario: admin)
      expect(lote.reload.estado).to eq('finalizado')
    end
  end

  describe '#finalizar_si_stock_agotado!' do
    it 'deja el evento que explica por qué cerró' do
      stock_del_lote(cantidad: 0, estado: 'agotado')

      lote.finalizar_si_stock_agotado!(usuario: admin)

      evento = lote.lote_eventos.where(estado_nuevo: 'finalizado').last
      expect(evento.descripcion).to include('Stock agotado')
    end

    # Un stock 'asignado' que quedó en cero es lo mismo que uno agotado: si no, un redondeo
    # dejaba el lote sin poder cerrar nunca.
    it 'cierra aunque un stock en cero haya quedado sin marcar como agotado' do
      stock_del_lote(cantidad: 0, estado: 'asignado')

      lote.finalizar_si_stock_agotado!(usuario: admin)

      expect(lote.reload.estado).to eq('finalizado')
    end
  end
end
