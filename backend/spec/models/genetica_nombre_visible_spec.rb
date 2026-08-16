require 'rails_helper'

# AC (Germán): "al crear una genética propia la vinculamos con una del INASE. Cada informe
# regulatorio va a salir con la genética del INASE que tiene vinculada, pero las etiquetas y los
# informes internos van a salir con las dos."
#
# Son DOS nombres para dos lectores distintos y no se pueden mezclar:
#   · `nombre_declarado` → lo que se presenta ante el organismo. SÓLO la variedad acreditada.
#   · `nombre_visible`   → puertas adentro. El propio, con la acreditada entre paréntesis.
RSpec.describe 'Cómo se nombra una genética', type: :model do
  let(:club) { create(:club) }

  let(:inase) do
    ActsAsTenant.without_tenant do
      Genetica.create!(nombre: 'CELOSA 10', tipo: 'hibrida', global: true,
                       registrada_inase: true, numero_registro_inase: 'INASE-123', club_id: nil, activa: true)
    end
  end

  let(:propia) do
    ActsAsTenant.with_tenant(club) do
      create(:genetica, club: club, nombre: 'Blue Sherbet', declarada_como: inase)
    end
  end

  describe 'puertas adentro' do
    it 'lleva las dos: la propia primero, la acreditada entre paréntesis' do
      expect(propia.nombre_visible).to eq('Blue Sherbet (CELOSA 10)')
    end

    # El separador NO es "x": en cannabis `A x B` es un CRUCE. "CELOSA 10 x Blue Sherbet" se
    # leería como que la planta es hija de esas dos, que es lo contrario de lo que dice.
    it 'sin la "x", que en cannabis significa un cruce' do
      expect(propia.nombre_visible).not_to include(' x ')
    end

    it 'una sin declarar se llama como se llama, sin paréntesis vacío' do
      suelta = ActsAsTenant.with_tenant(club) { create(:genetica, club: club, nombre: 'Casera') }

      expect(suelta.nombre_visible).to eq('Casera')
    end
  end

  describe 'ante el organismo' do
    it 'va SÓLO la variedad acreditada' do
      expect(propia.nombre_declarado).to eq('CELOSA 10')
      expect(propia.nombre_declarado).not_to include('Blue Sherbet')
    end

    it 'con su número de registro' do
      expect(propia.numero_inase_declarado).to eq('INASE-123')
    end

    # Una que no declara contra nada se presenta con su propio nombre: es lo único que hay.
    it 'sin declaración, el propio' do
      suelta = ActsAsTenant.with_tenant(club) { create(:genetica, club: club, nombre: 'Casera') }

      expect(suelta.nombre_declarado).to eq('Casera')
    end
  end
end
