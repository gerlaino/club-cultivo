require 'rails_helper'

# AC (Germán): "el registro contable de una dispensación con cuenta corriente no debería debitarse
# ya que la plata no está".
#
# La convención del proyecto es CONSERVADORA y asimétrica, y conviene tenerla escrita:
#   ingresos → PERCIBIDO: sólo lo cobrado (`MovimientoContable.ingresos` excluye `pagado: false`)
#   egresos  → DEVENGADO: lo que se debe cuenta aunque no esté pagado
#
# El asiento de una dispensa a cuenta corriente SÍ se crea, y está bien: la entrega ocurrió y
# tiene que quedar registrada con su costo y su trazabilidad. Lo que no puede es contar como plata
# que entró. Nace con `pagado: false` y es de ahí que cuelga todo lo demás.
RSpec.describe 'Contabilidad — una dispensa a cuenta corriente no es plata que entró', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club) }

  let(:paciente) do
    ActsAsTenant.with_tenant(club) do
      p = create(:paciente, club: club)
      p.create_cuenta_corriente!(club: club, saldo_disponible: 0, limite_credito: 100_000)
      p
    end
  end

  let(:stock) do
    ActsAsTenant.with_tenant(club) do
      lote = create(:lote, club: club, sala: create(:sala, club: club, sede: sede))
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca',
                     cantidad: 500, precio_sugerido_ars: 100)
    end
  end

  def dispensar!(total:)
    ActsAsTenant.with_tenant(club) do
      Dispensacion.create!(paciente: paciente, user: admin, stock: stock, sede: sede, cantidad: 5,
                           medio_pago: 'efectivo', aporte_socio_ars: total,
                           fecha_dispensacion: Time.zone.today)
    end
  end

  def cobrar!(disp, medio:, monto:)
    ActsAsTenant.with_tenant(club) do
      res = Dispensaciones::RegistrarCobro.call(dispensacion: disp, club: club, usuario: admin,
                                                medio: medio, monto: monto)
      expect(res.ok?).to be(true), "el cobro falló: #{res.error}"
      res
    end
  end

  describe 'el asiento' do
    it 'se crea, pero marcado como NO cobrado' do
      disp = dispensar!(total: 10_000)
      cobrar!(disp, medio: 'cuenta_corriente', monto: 10_000)

      mov = disp.movimientos_contables.last
      expect(mov).to be_present, 'la entrega tiene que quedar registrada igual'
      expect(mov.pagado).to be(false)
      expect(mov.medio_pago).to eq('cuenta_corriente')
    end

    it 'no entra en los ingresos del club' do
      disp = dispensar!(total: 10_000)
      cobrar!(disp, medio: 'cuenta_corriente', monto: 10_000)

      movs = ActsAsTenant.with_tenant(club) { MovimientoContable.where(club_id: club.id) }
      expect(movs.ingresos.sum(:monto_ars)).to eq(0)
      expect(movs.a_credito.sum(:monto_ars)).to eq(10_000)
    end

    it 'un cobro en efectivo SÍ entra' do
      disp = dispensar!(total: 10_000)
      cobrar!(disp, medio: 'efectivo', monto: 10_000)

      movs = ActsAsTenant.with_tenant(club) { MovimientoContable.where(club_id: club.id) }
      expect(movs.ingresos.sum(:monto_ars)).to eq(10_000)
      expect(movs.a_credito.sum(:monto_ars)).to eq(0)
    end

    # El caso del pago dividido: parte entra al cajón y parte queda debiendo.
    it 'partido, sólo cuenta la parte cobrada' do
      disp = dispensar!(total: 10_000)
      cobrar!(disp, medio: 'efectivo', monto: 6_000)
      cobrar!(disp, medio: 'cuenta_corriente', monto: 4_000)

      movs = ActsAsTenant.with_tenant(club) { MovimientoContable.where(club_id: club.id) }
      expect(movs.ingresos.sum(:monto_ars)).to eq(6_000)
      expect(movs.a_credito.sum(:monto_ars)).to eq(4_000)
    end
  end

  # El bug que reportó Germán: el asiento nacía bien, pero el P&L por unidad agrupaba por `tipo`
  # A MANO y se salteaba el scope `ingresos`, así que la plata sin cobrar aparecía como ingreso.
  describe 'el P&L por unidad' do
    def resumen
      sign_in_as(admin)
      get '/api/movimientos_contables/dashboard', headers: auth_headers
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body)
    end

    it 'no cuenta como ingreso lo que quedó a cuenta corriente' do
      disp = dispensar!(total: 10_000)
      cobrar!(disp, medio: 'cuenta_corriente', monto: 10_000)

      unidades = resumen['por_unidad'] || []
      expect(unidades.sum { |u| u['ingresos'].to_f }).to eq(0.0)
      expect(unidades.sum { |u| u['a_cobrar'].to_f }).to eq(10_000.0)
    end

    it 'lo cobrado en efectivo sí figura como ingreso' do
      disp = dispensar!(total: 10_000)
      cobrar!(disp, medio: 'efectivo', monto: 10_000)

      unidades = resumen['por_unidad'] || []
      expect(unidades.sum { |u| u['ingresos'].to_f }).to eq(10_000.0)
      expect(unidades.sum { |u| u['a_cobrar'].to_f }).to eq(0.0)
    end

    # Que el total no se pierda es la mitad del punto: esconder la deuda haría parecer que la
    # entrega nunca ocurrió.
    it 'partido, reparte entre cobrado y a cobrar sin perder el total' do
      disp = dispensar!(total: 10_000)
      cobrar!(disp, medio: 'efectivo', monto: 6_000)
      cobrar!(disp, medio: 'cuenta_corriente', monto: 4_000)

      unidades = resumen['por_unidad'] || []
      expect(unidades.sum { |u| u['ingresos'].to_f }).to eq(6_000.0)
      expect(unidades.sum { |u| u['a_cobrar'].to_f }).to eq(4_000.0)
    end
  end

  describe 'la cuenta corriente del paciente' do
    it 'se le debita el cupo, que es donde la deuda vive de verdad' do
      disp = dispensar!(total: 10_000)
      cobrar!(disp, medio: 'cuenta_corriente', monto: 10_000)

      cc = paciente.cuenta_corriente.reload
      expect(cc.saldo_disponible.to_f).to eq(-10_000.0)
      expect(cc.movimientos.where(tipo: 'debito').sum(:monto).to_f).to eq(-10_000.0)
    end

    it 'un cobro en efectivo no le toca el cupo' do
      disp = dispensar!(total: 10_000)
      cobrar!(disp, medio: 'efectivo', monto: 10_000)

      expect(paciente.cuenta_corriente.reload.saldo_disponible.to_f).to eq(0.0)
    end
  end
end
