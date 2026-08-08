require 'rails_helper'

# Los clubes cultivan genéticas que no están inscriptas en el INASE y las etiquetan contra una
# variedad que sí lo está. Antes eso vivía sólo en la etiqueta de papel: la app mostraba el
# nombre de fantasía y "sin registrar", que no es lo que el club presenta ante el organismo.
RSpec.describe Genetica, 'declaración ante el INASE' do
  let(:club) { create(:club) }

  # Las variedades inscriptas son GLOBALES (club_id nil): un catálogo compartido, no una copia
  # por club.
  let!(:inscripta) do
    ActsAsTenant.without_tenant do
      Genetica.create!(nombre: 'ANANDA001', global: true, club_id: nil,
                       registrada_inase: true, numero_registro_inase: 'INASE-12345')
    end
  end

  let(:propia) { create(:genetica, club: club, nombre: 'Northern Lights', registrada_inase: false) }

  describe 'el vínculo' do
    it 'acepta declarar una genética propia contra una inscripta' do
      propia.declarada_como = inscripta

      expect(propia).to be_valid
    end

    it 'rechaza declararla contra una que no está inscripta' do
      otra = create(:genetica, club: club, nombre: 'Critical', registrada_inase: false)
      propia.declarada_como = otra

      expect(propia).not_to be_valid
      expect(propia.errors[:declarada_como].join).to match(/inscripta en el INASE/)
    end

    it 'rechaza que una variedad ya inscripta se declare contra otra' do
      inscripta.declarada_como_id = inscripta.id

      expect(inscripta).not_to be_valid
      expect(inscripta.errors[:declarada_como].join).to match(/ya está inscripta/)
    end

    it 'rechaza declararse contra sí misma' do
      propia.save!
      propia.declarada_como_id = propia.id

      expect(propia).not_to be_valid
    end

    it 'declarar es opcional: sin vínculo sigue siendo válida' do
      expect(propia).to be_valid
      expect(propia.declarada_como).to be_nil
    end
  end

  describe '#nombre_declarado' do
    it 'devuelve la variedad inscripta cuando hay declaración' do
      propia.update!(declarada_como: inscripta)

      expect(propia.nombre_declarado).to eq('ANANDA001')
    end

    # Puertas adentro el cultivador trabaja con el nombre real: sólo los informes
    # regulatorios usan el declarado.
    it 'devuelve el nombre propio cuando no hay declaración' do
      expect(propia.nombre_declarado).to eq('Northern Lights')
    end

    it 'una variedad inscripta se nombra a sí misma' do
      expect(inscripta.nombre_declarado).to eq('ANANDA001')
    end
  end

  describe '#numero_inase_declarado' do
    it 'toma el número de la variedad contra la que se declara' do
      propia.update!(declarada_como: inscripta)

      expect(propia.numero_inase_declarado).to eq('INASE-12345')
    end

    it 'una genética sin declarar no tiene número' do
      expect(propia.numero_inase_declarado).to be_nil
    end
  end

  describe '#acreditada_inase?' do
    it 'lo está la inscripta' do
      expect(inscripta).to be_acreditada_inase
    end

    it 'lo está la declarada' do
      propia.update!(declarada_como: inscripta)

      expect(propia).to be_acreditada_inase
    end

    it 'no lo está la que no es ninguna de las dos' do
      expect(propia).not_to be_acreditada_inase
    end
  end

  describe '.declarables' do
    it 'ofrece sólo las variedades inscriptas del catálogo global' do
      propia.save!

      expect(Genetica.declarables).to include(inscripta)
      expect(Genetica.declarables).not_to include(propia)
    end
  end

  # Si se borra la variedad contra la que se declaraba, la genética no se cae: queda sin
  # declarar y vuelve a aparecer como pendiente.
  describe 'cuando se borra la variedad declarada' do
    it 'la genética queda sin declarar' do
      propia.update!(declarada_como: inscripta)

      ActsAsTenant.without_tenant { inscripta.destroy }

      expect(propia.reload.declarada_como_id).to be_nil
      expect(propia).not_to be_acreditada_inase
    end
  end
end
