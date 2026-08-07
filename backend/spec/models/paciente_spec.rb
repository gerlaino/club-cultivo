require 'rails_helper'

RSpec.describe Paciente, type: :model do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  def build_paciente(attrs = {})
    build(:paciente, { club: club, created_by: admin }.merge(attrs))
  end

  def create_paciente(attrs = {})
    create(:paciente, { club: club, created_by: admin }.merge(attrs))
  end

  # ── validaciones ──────────────────────────────────────────────────────────

  describe 'validaciones' do
    it 'es válido con datos correctos' do
      expect(build_paciente).to be_valid
    end

    it 'requiere nombre' do
      expect(build_paciente(nombre: nil)).not_to be_valid
    end

    it 'requiere apellido' do
      expect(build_paciente(apellido: nil)).not_to be_valid
    end

    it 'requiere fecha_nacimiento' do
      expect(build_paciente(fecha_nacimiento: nil)).not_to be_valid
    end

    it 'requiere fecha_nacimiento en el pasado' do
      expect(build_paciente(fecha_nacimiento: Time.zone.today)).not_to be_valid
    end

    context 'dni_normalizado' do
      it 'rechaza dni con menos de 7 dígitos' do
        p = build_paciente(dni: '123456')
        p.valid?
        expect(p.errors[:dni_normalizado]).not_to be_empty
      end

      it 'rechaza dni con más de 9 dígitos' do
        p = build_paciente(dni: '1234567890')
        p.valid?
        expect(p.errors[:dni_normalizado]).not_to be_empty
      end

      it 'acepta dni de 8 dígitos' do
        expect(build_paciente(dni: '12345678')).to be_valid
      end

      it 'normaliza dni extrayendo solo dígitos' do
        p = build_paciente(dni: '12.345.678')
        p.valid?
        expect(p.dni_normalizado).to eq('12345678')
      end

      it 'es único por dni_normalizado' do
        create_paciente(dni: '12345678')
        expect(build_paciente(dni: '12.345.678')).not_to be_valid
      end
    end
  end

  # ── callbacks ─────────────────────────────────────────────────────────────

  describe 'callbacks' do
    it 'asigna carnet_token al crear' do
      p = create_paciente
      expect(p.carnet_token).to be_present
    end

    it 'no sobreescribe carnet_token existente' do
      token = SecureRandom.uuid
      p = create_paciente(carnet_token: token)
      expect(p.carnet_token).to eq(token)
    end
  end

  # ── scopes ────────────────────────────────────────────────────────────────

  describe 'scopes' do
    describe '.for_club' do
      it 'filtra por club' do
        otro_club = create(:club)
        otro_admin = create(:user, :admin, club: otro_club)
        p_mio  = create_paciente
        _p_otro = ActsAsTenant.with_tenant(otro_club) { create(:paciente, club: otro_club, created_by: otro_admin) }
        expect(Paciente.for_club(club.id)).to contain_exactly(p_mio)
      end
    end

    describe '.reprocann_por_vencer' do
      it 'incluye pacientes con vencimiento en los próximos 30 días' do
        p = create_paciente(reprocann_vencimiento: 15.days.from_now)
        expect(Paciente.reprocann_por_vencer).to include(p)
      end

      it 'excluye pacientes ya vencidos' do
        p = create_paciente(reprocann_vencimiento: 1.day.ago)
        expect(Paciente.reprocann_por_vencer).not_to include(p)
      end

      it 'excluye pacientes con vencimiento más allá de 30 días' do
        # 45 días: bien lejos del borde de los 30 días (evita flake por TZ/hora)
        p = create_paciente(reprocann_vencimiento: 45.days.from_now)
        expect(Paciente.reprocann_por_vencer).not_to include(p)
      end

      it 'excluye pacientes sin vencimiento registrado' do
        p = create_paciente(reprocann_vencimiento: nil)
        expect(Paciente.reprocann_por_vencer).not_to include(p)
      end
    end

    describe '.con_seguimiento / .sin_seguimiento' do
      it 'filtra por seguimiento médico' do
        con  = create_paciente(con_seguimiento_medico: true)
        sin_ = create_paciente(con_seguimiento_medico: false)
        expect(Paciente.con_seguimiento).to include(con)
        expect(Paciente.con_seguimiento).not_to include(sin_)
        expect(Paciente.sin_seguimiento).to include(sin_)
      end
    end
  end

  # ── métodos de instancia ──────────────────────────────────────────────────

  describe '#nombre_completo' do
    it 'combina nombre y apellido' do
      p = build_paciente(nombre: 'Juan', apellido: 'Pérez')
      expect(p.nombre_completo).to eq('Juan Pérez')
    end
  end

  describe '#dispensado_mes_actual_g' do
    it 'suma las dispensaciones del mes actual' do
      sede     = create(:sede, club: club, created_by: admin)
      lote     = create(:lote, club: club, sala: create(:sala, club: club, sede: sede, created_by: admin))
      stock    = Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100)
      paciente = create_paciente
      Dispensacion.create!(
        paciente: paciente, user: admin, stock: stock,
        cantidad: 25, fecha_dispensacion: Time.zone.today, medio_pago: 'efectivo'
      )
      expect(paciente.dispensado_mes_actual_g).to eq(25.0)
    end
  end

  # ── porcentaje_limite_mensual ─────────────────────────────────────────────

  describe '#porcentaje_limite_mensual' do
    let(:sede)     { create(:sede, club: club, created_by: admin) }
    let(:lote)     { create(:lote, club: club, sala: create(:sala, club: club, sede: sede, created_by: admin)) }
    let!(:stock)   { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 200) }
    let(:paciente) { create_paciente(limite_dispensacion_mensual_g: 40) }

    it 'devuelve 0.0 cuando no hay dispensaciones en el mes' do
      expect(paciente.porcentaje_limite_mensual).to eq(0.0)
    end

    it 'calcula el porcentaje correcto cuando hay dispensaciones' do
      Dispensacion.create!(paciente: paciente, user: admin, stock: stock,
        cantidad: 20, fecha_dispensacion: Time.zone.today, medio_pago: 'efectivo')
      expect(paciente.porcentaje_limite_mensual).to eq(50.0)
    end

    it 'topa en 100 aunque se exceda el límite' do
      Dispensacion.create!(paciente: paciente, user: admin, stock: stock,
        cantidad: 40, fecha_dispensacion: Time.zone.today, medio_pago: 'efectivo')
      # simular 50g ignorando la validación
      Dispensacion.where(paciente: paciente).last.update_column(:cantidad, 50)
      expect(paciente.porcentaje_limite_mensual).to eq(100.0)
    end

    it 'devuelve nil si no hay límite configurado' do
      p = create_paciente(limite_dispensacion_mensual_g: nil)
      expect(p.porcentaje_limite_mensual).to be_nil
    end

    it 'devuelve nil si el límite es 0' do
      p = create_paciente(limite_dispensacion_mensual_g: 0)
      expect(p.porcentaje_limite_mensual).to be_nil
    end
  end

  # ── saldo_cc / limite_cc ──────────────────────────────────────────────────

  describe '#saldo_cc y #limite_cc' do
    context 'paciente con CuentaCorriente' do
      before do
        CuentaCorriente.create!(
          paciente: paciente, club: club,
          saldo_disponible: 300, limite_credito: 500
        )
      end

      let(:paciente) { create_paciente }

      it '#saldo_cc devuelve el saldo disponible en ARS' do
        expect(paciente.saldo_cc).to eq(300.0)
      end

      it '#limite_cc devuelve el límite de crédito en ARS' do
        expect(paciente.limite_cc).to eq(500.0)
      end
    end

    context 'paciente sin CuentaCorriente' do
      let(:paciente) { create_paciente }

      it '#saldo_cc devuelve nil' do
        expect(paciente.saldo_cc).to be_nil
      end

      it '#limite_cc devuelve nil' do
        expect(paciente.limite_cc).to be_nil
      end
    end
  end

  # ── acts_as_paranoid: soft delete ─────────────────────────────────────────

  describe 'soft delete (acts_as_paranoid)' do
    let(:paciente) { create_paciente }

    it 'setea deleted_at al hacer destroy' do
      paciente.destroy
      expect(Paciente.with_deleted.find(paciente.id).deleted_at).not_to be_nil
    end

    it 'excluye al paciente del default scope tras destroy' do
      paciente.destroy
      expect(Paciente.where(id: paciente.id)).to be_empty
    end

    it 'puede recuperar el registro eliminado con with_deleted' do
      paciente.destroy
      expect(Paciente.with_deleted.where(id: paciente.id)).not_to be_empty
    end

    it 'restore! reactiva el paciente eliminado' do
      paciente.destroy
      paciente.restore!
      expect(Paciente.where(id: paciente.id)).not_to be_empty
    end
  end

  describe '#direccion_entrega' do
    it 'usa el domicilio cuando no hay dirección de envío' do
      p = build(:paciente, domicilio_calle: 'Corrientes', domicilio_ciudad: 'CABA',
                           envio_calle: nil)
      expect(p.direccion_entrega[:calle]).to eq('Corrientes')
      expect(p.direccion_entrega[:ciudad]).to eq('CABA')
    end

    it 'prefiere la dirección de envío cuando está cargada' do
      p = build(:paciente, domicilio_calle: 'Corrientes', domicilio_ciudad: 'CABA',
                           envio_calle: 'Rivadavia', envio_ciudad: 'Quilmes')
      expect(p.direccion_entrega[:calle]).to eq('Rivadavia')
      expect(p.direccion_entrega[:ciudad]).to eq('Quilmes')
    end
  end
end
