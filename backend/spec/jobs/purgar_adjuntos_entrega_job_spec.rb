require 'rails_helper'

# Las imágenes de una entrega viven 30 días. Lo que se borra es la IMAGEN, nunca el registro —
# y el hueco tiene que decir que hubo firma, o una entrega vieja se ve idéntica a una donde
# nadie firmó.
RSpec.describe PurgarAdjuntosEntregaJob, type: :job do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, tipo: 'social') }
  let(:lote)     { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }
  let(:paciente) { ActsAsTenant.with_tenant(club) { create(:paciente, club: club) } }
  let(:stock) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 500, estado: 'asignado', disponibilidad: 'ambas',
                     precio_sugerido_ars: 100, fecha_elaboracion: Time.zone.today - 90)
    end
  end

  # Un bloque de RSpec no abre scope de constante: `FIRMA = ...` acá adentro se define en Object.
  let(:firma_png) { 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUg' }

  # Una entrega hecha hace `dias`, con firma y (opcionalmente) foto.
  def entrega(dias:, firma: firma_png, con_foto: false)
    ActsAsTenant.with_tenant(club) do
      d = Dispensacion.create!(paciente: paciente, user: admin, stock: stock, sede: sede,
                               cantidad: 1, medio_pago: 'efectivo', aporte_socio_ars: 100,
                               fecha_dispensacion: Time.zone.today - dias)
      d.update_columns(estado_envio: 'entregado', con_envio: true,
                       entregado_at: dias.days.ago, firma_entrega_data: firma)
      if con_foto
        d.comprobante_entrega.attach(io: StringIO.new('foto'), filename: 'entrega.jpg',
                                     content_type: 'image/jpeg')
      end
      d
    end
  end

  describe 'qué borra' do
    it 'borra la firma de una entrega pasados los 30 días' do
      vieja = entrega(dias: 40)

      expect { described_class.new.perform }
        .to change { vieja.reload.firma_entrega_data }.from(firma_png).to(nil)
    end

    it 'borra también la foto de la entrega' do
      vieja = entrega(dias: 40, con_foto: true)

      described_class.new.perform

      expect(vieja.reload.comprobante_entrega).not_to be_attached
    end

    it 'no toca una entrega de esta semana' do
      reciente = entrega(dias: 3)

      described_class.new.perform

      expect(reciente.reload.firma_entrega_data).to eq(firma_png)
    end
  end

  describe 'qué NO borra' do
    # El comprobante de PAGO es la foto de una transferencia que trajo el paciente: no la emitió
    # el club y nadie la puede regenerar. Además cuelga del Cobro, que usan también el mostrador
    # y las reservas — un barrido ciego se llevaría el respaldo de un asiento.
    it 'el comprobante de pago sobrevive aunque la entrega sea vieja' do
      vieja = entrega(dias: 40)
      cobro = ActsAsTenant.with_tenant(club) do
        c = Cobro.create!(dispensacion: vieja, club: club, created_by: admin, medio: 'transferencia',
                          monto_ars: 100, contexto: 'entrega')
        c.comprobante.attach(io: StringIO.new('transferencia'), filename: 'pago.jpg',
                             content_type: 'image/jpeg')
        c
      end

      described_class.new.perform

      expect(cobro.reload.comprobante).to be_attached
    end

    it 'la dispensación sigue entera: es registro contable' do
      vieja = entrega(dias: 40)

      described_class.new.perform
      vieja.reload

      expect(vieja.estado_envio).to eq('entregado')
      expect(vieja.entregado_at).to be_present
      expect(vieja).to be_persisted
    end
  end

  describe 'el hueco habla' do
    it 'deja el evento en la bitácora del envío diciendo qué había' do
      vieja = entrega(dias: 40, con_foto: true)

      described_class.new.perform

      evento = vieja.reload.historial_envio.find { |e| e['evento'] == 'imagenes_purgadas' }
      expect(evento).to be_present
      expect(evento['firma']).to be(true)
      expect(evento['foto']).to be(true)
    end

    it 'no marca la dispensa como modificada hoy: borrar por antigüedad no es una edición' do
      vieja = entrega(dias: 40)
      antes = vieja.reload.updated_at

      described_class.new.perform

      expect(vieja.reload.updated_at).to be_within(1.second).of(antes)
    end
  end

  it 'corriendo dos veces no vuelve a anotar el evento' do
    entrega(dias: 40)

    described_class.new.perform
    expect { described_class.new.perform }
      .not_to(change { Dispensacion.with_deleted.sum('jsonb_array_length(historial_envio)') })
  end
end
