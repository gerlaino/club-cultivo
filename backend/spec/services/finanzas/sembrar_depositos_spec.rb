require 'rails_helper'

RSpec.describe Finanzas::SembrarDepositos, type: :service do
  let(:club) { create(:club) }

  def con_tenant(&blk) = ActsAsTenant.with_tenant(club, &blk)

  describe '#call' do
    it 'siembra los depósitos de sistema base (sin Salón si no hay bar)' do
      described_class.new(club).call
      con_tenant do
        claves = club.depositos.sistema.pluck(:clave_sistema)
        expect(claves).to contain_exactly('cultivo', 'general', 'dispensacion')
        expect(club.depositos.find_by(clave_sistema: 'cultivo')).to be_es_sistema
      end
    end

    it 'incluye el depósito Salón solo si el club tiene el feature bar' do
      club.update!(features: club.features.merge('bar' => true))
      described_class.new(club).call
      con_tenant do
        expect(club.depositos.pluck(:clave_sistema)).to include('salon')
      end
    end

    it 'vincula cada depósito de sistema a su área (Cultivo→cultivo, General→administración)' do
      described_class.new(club).call
      con_tenant do
        expect(club.depositos.find_by(clave_sistema: 'cultivo').unidad_negocio.tipo).to eq('cultivo')
        expect(club.depositos.find_by(clave_sistema: 'general').unidad_negocio.tipo).to eq('administracion')
        expect(club.depositos.find_by(clave_sistema: 'dispensacion').unidad_negocio.tipo).to eq('dispensario')
      end
    end

    it 'backfillea los insumos a su depósito según el tipo' do
      con_tenant do
        club.insumos.create!(nombre: 'Fertilizante', unidad_medida: 'litro', tipo: 'cultivo')
        club.insumos.create!(nombre: 'Lavandina', unidad_medida: 'litro', tipo: 'general')
      end
      described_class.new(club).call
      con_tenant do
        cultivo = club.insumos.find_by(nombre: 'Fertilizante')
        general = club.insumos.find_by(nombre: 'Lavandina')
        expect(cultivo.deposito.clave_sistema).to eq('cultivo')
        expect(general.deposito.clave_sistema).to eq('general')
      end
    end

    it 'es idempotente: no duplica ni pisa el nombre editado por el admin' do
      described_class.new(club).call
      con_tenant { club.depositos.find_by(clave_sistema: 'cultivo').update!(nombre: 'Mi Cultivo') }
      expect { described_class.new(club).call }.not_to change { con_tenant { club.depositos.count } }
      con_tenant do
        expect(club.depositos.find_by(clave_sistema: 'cultivo').nombre).to eq('Mi Cultivo')
      end
    end
  end
end
