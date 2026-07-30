require 'rails_helper'

# Multi-sede: los depósitos del sistema se siembran POR SEDE (General en todas; Cultivo en
# producción; Salón/Dispensario en social/mixta con bar), y lo legacy club-wide se sede-ifica.
RSpec.describe Finanzas::SembrarDepositos, type: :service do
  let(:club)    { create(:club, features: { 'bar' => true }) }
  let(:admin)   { create(:user, :admin, club: club) }
  let!(:prod)   { create(:sede, club: club, created_by: admin, tipo: 'produccion') }
  let!(:social) { create(:sede, club: club, created_by: admin, tipo: 'social') }

  # Fija el tenant para todo el ejemplo (setup incluido); se restaura solo.
  around { |ex| ActsAsTenant.with_tenant(club) { ex.run } }
  def con_tenant(&blk) = yield

  describe 'siembra por sede según el tipo' do
    before { described_class.new(club).call }

    it 'General en TODAS las sedes' do
      con_tenant { expect(club.depositos.where(clave_sistema: 'general').pluck(:sede_id)).to contain_exactly(prod.id, social.id) }
    end

    it 'Cultivo solo en sedes de producción' do
      con_tenant { expect(club.depositos.where(clave_sistema: 'cultivo').pluck(:sede_id)).to contain_exactly(prod.id) }
    end

    it 'Salón y Dispensario solo en social/mixta (Salón además requiere bar)' do
      con_tenant do
        expect(club.depositos.where(clave_sistema: 'salon').pluck(:sede_id)).to contain_exactly(social.id)
        expect(club.depositos.where(clave_sistema: 'dispensacion').pluck(:sede_id)).to contain_exactly(social.id)
      end
    end

    it 'vincula cada depósito a su área' do
      con_tenant { expect(club.depositos.find_by(clave_sistema: 'cultivo', sede_id: prod.id).unidad_negocio.tipo).to eq('cultivo') }
    end

    it 'sin bar, no siembra Salón' do
      otro = create(:club) # sin feature bar
      otro_admin = create(:user, :admin, club: otro)
      ActsAsTenant.with_tenant(otro) do
        create(:sede, club: otro, created_by: otro_admin, tipo: 'social')
        described_class.new(otro).call
        expect(otro.depositos.where(clave_sistema: 'salon')).to be_empty
      end
    end
  end

  describe 'sede-ificación de insumos' do
    it 'reasigna el insumo al depósito de SU sede' do
      f = con_tenant { club.insumos.create!(nombre: 'Fertilizante', unidad_medida: 'litro', tipo: 'cultivo', sede_id: prod.id) }
      described_class.new(club).call
      con_tenant do
        dep = f.reload.deposito
        expect(dep.clave_sistema).to eq('cultivo')
        expect(dep.sede_id).to eq(prod.id)
      end
    end

    it 'un insumo pool (sin sede) cae en la sede principal (la más antigua)' do
      l = con_tenant { club.insumos.create!(nombre: 'Lavandina', unidad_medida: 'litro', tipo: 'general', sede_id: nil) }
      described_class.new(club).call
      con_tenant do
        l.reload
        expect(l.deposito.clave_sistema).to eq('general')
        expect(l.deposito.sede_id).to eq(prod.id)
        expect(l.sede_id).to eq(prod.id)
      end
    end
  end

  describe 'migración de depósitos legacy (club-wide → por sede)' do
    it 'reasigna los insumos del depósito club-wide y lo retira' do
      old = club.depositos.create!(clave_sistema: 'general', sede_id: nil, nombre: 'General', es_sistema: true, activo: true)
      old_id = old.id
      club.insumos.create!(nombre: 'Trapos', unidad_medida: 'unidad', tipo: 'general', sede_id: social.id, deposito: old)

      described_class.new(club).call

      trapos = club.insumos.find_by(nombre: 'Trapos')
      expect(trapos.deposito.sede_id).to eq(social.id)     # migrado a la sede
      expect(trapos.deposito.id).not_to eq(old_id)
      expect(club.depositos.find_by(id: old_id)).to be_nil # el club-wide viejo, retirado
    end

    # Sede es soft-delete: un insumo puede apuntar a una sede que ya no existe. Antes no había
    # depósito destino, el insumo no se movía y el legacy no se podía retirar NUNCA: el club veía
    # "General"/"Cultivo" duplicados (el legacy + el de cada sede) para siempre.
    it 'migra igual los insumos de una sede borrada (caen en la sede principal)' do
      borrada = create(:sede, club: club, created_by: admin, tipo: 'social')
      old = club.depositos.create!(clave_sistema: 'general', sede_id: nil, nombre: 'General', es_sistema: true, activo: true)
      old_id = old.id
      club.insumos.create!(nombre: 'Lampazo', unidad_medida: 'unidad', tipo: 'general', sede_id: borrada.id, deposito: old)
      borrada.soft_delete!

      described_class.new(club).call

      lampazo = club.insumos.find_by(nombre: 'Lampazo')
      expect(lampazo.deposito_id).not_to eq(old_id)
      expect(lampazo.deposito.sede_id).to eq(club.sedes.order(:id).first.id) # principal
      expect(club.depositos.find_by(id: old_id)).to be_nil                   # ya se puede retirar
      expect(club.depositos.where(clave_sistema: 'general').count).to eq(club.sedes.count) # sin duplicados
    end
  end

  # La validación de unicidad no protege de una race (la siembra corre desde un before_action y dos
  # requests simultáneos creaban dos "General" para la misma sede). Lo garantiza la tabla.
  describe 'unicidad a nivel base' do
    before { described_class.new(club).call }

    it 'la base rechaza un segundo depósito con la misma clave y sede, aun saltando validaciones' do
      dup = { club_id: club.id, sede_id: prod.id, clave_sistema: 'general', nombre: 'General',
              es_sistema: true, activo: true, orden: 0, created_at: Time.current, updated_at: Time.current }

      expect { Deposito.insert_all!([dup]) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'permite el mismo nombre en OTRA sede' do
      con_tenant do
        expect(club.depositos.where(clave_sistema: 'general').pluck(:sede_id))
          .to contain_exactly(prod.id, social.id)
      end
    end

    it 'no se cae si otro proceso ya sembró el depósito (la siembra absorbe el duplicado)' do
      con_tenant do
        expect { described_class.new(club).call }.not_to raise_error
        expect(club.depositos.where(clave_sistema: 'general', sede_id: prod.id).count).to eq(1)
      end
    end

    # Post-deduplicación queda un duplicado RETIRADO al lado del vivo. Si la siembra agarraba el
    # retirado, el restore chocaba contra el índice único (dos vivos con la misma clave) → 500.
    it 'con un duplicado ya retirado, no lo revive: se queda con el vivo' do
      con_tenant do
        vivo = club.depositos.find_by(clave_sistema: 'general', sede_id: prod.id)
        retirado = club.depositos.create!(clave_sistema: nil, sede_id: prod.id, nombre: 'General',
                                         es_sistema: true, activo: true)
        # Simula el duplicado que dejó la deduplicación: misma clave, retirado. El orden importa:
        # el índice único es parcial (clave_sistema NOT NULL AND deleted_at IS NULL), así que hay
        # que retirarlo PRIMERO; ponerle la clave estando vivo choca contra el índice en el acto.
        retirado.destroy!
        retirado.update_column(:clave_sistema, 'general')

        expect { described_class.new(club).call }.not_to raise_error
        expect(club.depositos.where(clave_sistema: 'general', sede_id: prod.id).pluck(:id)).to eq([vivo.id])
        expect(Deposito.unscoped.find(retirado.id).deleted_at).to be_present
      end
    end
  end

  describe 'idempotencia' do
    it 'no duplica ni pisa el nombre editado por el admin' do
      described_class.new(club).call
      con_tenant { club.depositos.find_by(clave_sistema: 'cultivo', sede_id: prod.id).update!(nombre: 'Mi Cultivo') }
      expect { described_class.new(club).call }.not_to change { con_tenant { club.depositos.count } }
      con_tenant { expect(club.depositos.find_by(clave_sistema: 'cultivo', sede_id: prod.id).nombre).to eq('Mi Cultivo') }
    end
  end
end
