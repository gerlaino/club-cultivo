require 'rails_helper'

# TEN-01 — Aislamiento multi-tenant a nivel modelo (acts_as_tenant).
# Garantía: con un tenant fijado (todo request autenticado), las queries de los
# modelos de club se auto-scopean por club_id, aunque el controller olvide scopear
# a mano. Es la red de defensa en profundidad. Sin tenant (jobs/público) no rompe.
RSpec.describe 'Multi-tenancy (acts_as_tenant)', type: :model do
  let(:club_a)  { create(:club) }
  let(:club_b)  { create(:club) }
  let(:admin_a) { create(:user, :admin, club: club_a) }
  let(:admin_b) { create(:user, :admin, club: club_b) }

  describe 'auto-scoping por tenant' do
    it 'oculta registros de otro club aunque la query no scopee a mano' do
      pac_a = ActsAsTenant.with_tenant(club_a) { create(:paciente, club: club_a, created_by: admin_a) }

      ActsAsTenant.with_tenant(club_b) do
        expect(Paciente.where(id: pac_a.id)).to be_empty
        expect { Paciente.find(pac_a.id) }.to raise_error(ActiveRecord::RecordNotFound)
        expect(Paciente.count).to eq(0)
      end

      ActsAsTenant.with_tenant(club_a) do
        expect(Paciente.find(pac_a.id)).to eq(pac_a)
      end
    end
  end

  describe 'sin tenant (jobs de Sidekiq / endpoints públicos)' do
    it 'no rompe: las queries no se scopean (require_tenant=false)' do
      ActsAsTenant.with_tenant(club_a) { create(:paciente, club: club_a, created_by: admin_a) }
      ActsAsTenant.with_tenant(club_b) { create(:paciente, club: club_b, created_by: admin_b) }

      ActsAsTenant.without_tenant do
        expect(Paciente.count).to be >= 2
      end
    end
  end

  describe 'uniqueness GLOBAL de DNI (REPROCANN)' do
    it 'rechaza un DNI ya registrado en otro club aun con tenant fijado' do
      ActsAsTenant.with_tenant(club_a) { create(:paciente, club: club_a, dni: '40555666', created_by: admin_a) }

      ActsAsTenant.with_tenant(club_b) do
        dup = build(:paciente, club: club_b, dni: '40555666', created_by: admin_b)
        expect(dup).not_to be_valid
        expect(dup.errors[:dni_normalizado]).to be_present
      end
    end
  end

  describe 'genéticas globales (has_global_records)' do
    it 'son visibles desde cualquier club además de las propias' do
      global = ActsAsTenant.without_tenant do
        Genetica.create!(nombre: 'Global Cat', tipo: 'hibrida', global: true,
                         registrada_inase: true, club_id: nil, activa: true)
      end
      propia_a = ActsAsTenant.with_tenant(club_a) { Genetica.create!(nombre: 'Propia A', tipo: 'indica', club_id: club_a.id, activa: true) }

      ActsAsTenant.with_tenant(club_b) do
        ids = Genetica.all.pluck(:id)
        expect(ids).to include(global.id)
        expect(ids).not_to include(propia_a.id)
      end
    end
  end
end
