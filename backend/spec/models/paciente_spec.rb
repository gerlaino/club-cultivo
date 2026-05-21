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
      expect(build_paciente(fecha_nacimiento: Date.today)).not_to be_valid
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
        _p_otro = create(:paciente, club: otro_club, created_by: otro_admin)
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
        p = create_paciente(reprocann_vencimiento: 31.days.from_now)
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
        cantidad: 25, fecha_dispensacion: Date.today, medio_pago: 'efectivo'
      )
      expect(paciente.dispensado_mes_actual_g).to eq(25.0)
    end
  end
end
