require 'rails_helper'

# AC (recorrido del 20-oct-2026): en el Club Modelo —lo que se le muestra a un cliente— cada
# dispensa tenía su línea duplicada: dos renglones de $30.904 y un total de $30.904. Una dispensa
# del demo tiene que verse como una de verdad: una línea por producto y la suma que cierra.
RSpec.describe Clubs::SembrarDemo do
  it 'cada dispensa del demo tiene una sola línea y su total es la suma de las líneas' do
    described_class.call(slug: 'demo_lineas', pacientes: 4, dispensaciones: 12, lotes: 3)

    club = Club.unscoped.find_by!(slug: 'demo_lineas')
    ActsAsTenant.with_tenant(club) do
      disps = Dispensacion.joins(:paciente).where(pacientes: { club_id: club.id }).includes(:items)
      expect(disps).not_to be_empty
      disps.each do |d|
        expect(d.items.size).to eq(1), "la dispensa ##{d.id} tiene #{d.items.size} líneas"
        expect(d.items.sum(&:cantidad)).to eq(d.cantidad)
      end
    end
  end
end
