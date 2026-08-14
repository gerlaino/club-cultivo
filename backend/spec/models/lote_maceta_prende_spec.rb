require 'rails_helper'

# AC (Germán): "al separar un lote enraizado, le saqué 5 plantas y las puse en maceta de 0,5:
# ya deberían estar en vegetativo".
#
# La regla que faltaba: PONER EN MACETA ES PRENDER. Enraizado ⇔ sin maceta — el que enraíza vive
# en taco o bandeja, y por eso pasar a vegetativo ya exigía indicar la maceta. La vuelta no
# existía, así que quedaban lotes "enraizando" con maceta de 5 L, que es un estado imposible.
RSpec.describe 'Poner en maceta prende el lote', type: :model do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin, kind: 'vegetativo') }

  # El evento de cambio de fase necesita autor (`lote_eventos.user_id` es NOT NULL): en un
  # request lo pone ApplicationController, acá se simula.
  before { Current.user = admin }
  after  { Current.user = nil }

  def lote_enraizando(plantas: 3)
    lote = create(:lote, club: club, sala: sala, estado: 'enraizado')
    create_list(:plant, plantas, lote: lote, club: club, state: 'enraizado')
    lote.update_column(:plants_count, plantas)
    lote.reload
  end

  describe 'editando el lote' do
    it 'asignarle maceta lo pasa a vegetativo' do
      lote = lote_enraizando

      lote.update!(tamanio_maceta: 0.5)

      expect(lote.reload.estado).to eq('vegetativo')
    end

    it 'y arrastra a sus plantas: no pueden quedar enraizando adentro de un lote en vegetativo' do
      lote = lote_enraizando

      lote.update!(tamanio_maceta: 0.5)

      expect(lote.plants.pluck(:state).uniq).to eq(['vegetativo'])
    end

    it 'lo deja anotado en la historia del lote' do
      lote = lote_enraizando

      expect { lote.update!(tamanio_maceta: 3) }
        .to change { lote.lote_eventos.where(tipo: 'cambio_estado', estado_nuevo: 'vegetativo').count }.by(1)
    end

    # Sin maceta sigue enraizando: la bandeja no es una maceta.
    it 'guardar otra cosa no lo mueve de fase' do
      lote = lote_enraizando

      lote.update!(notes: 'sigue en bandeja')

      expect(lote.reload.estado).to eq('enraizado')
    end

    # Un lote que YA quedó en ese estado contradictorio tiene que poder corregirse: si la regla
    # fuera una validación, no se le podría ni tocar el nombre.
    it 'no rompe un lote viejo que ya tenía maceta estando enraizado' do
      lote = lote_enraizando
      lote.update_columns(estado: 'enraizado', tamanio_maceta: 5)

      expect { lote.reload.update!(notes: 'corrijo una nota') }.not_to raise_error
      expect(lote.reload.estado).to eq('enraizado')
    end
  end

  describe 'desprendiendo un lote enraizando' do
    it 'el hijo que va a maceta nace en vegetativo' do
      lote = lote_enraizando(plantas: 8)

      res = Lotes::Desprender.call(lote: lote, usuario: admin, cantidad: 5, tamanio_maceta: '0.5')

      expect(res).to be_ok
      expect(res.lote_nuevo.estado).to eq('vegetativo')
      expect(res.lote_nuevo.tamanio_maceta.to_f).to eq(0.5)
    end

    it 'con sus plantas en vegetativo' do
      lote = lote_enraizando(plantas: 8)

      res = Lotes::Desprender.call(lote: lote, usuario: admin, cantidad: 5, tamanio_maceta: '0.5')

      expect(res.lote_nuevo.plants.pluck(:state).uniq).to eq(['vegetativo'])
    end

    # La línea de tiempo del padre llega hasta el enraizado; el salto a vegetativo es del hijo y
    # es de hoy. Sin el evento, su fecha de inicio de vegetativo cae a start_date y la analítica
    # le cuenta días de más.
    it 'y con el evento que fecha su paso a vegetativo' do
      lote = lote_enraizando(plantas: 8)

      res = Lotes::Desprender.call(lote: lote, usuario: admin, cantidad: 5, tamanio_maceta: '0.5')

      evento = res.lote_nuevo.lote_eventos.find_by(tipo: 'cambio_estado', estado_nuevo: 'vegetativo')
      expect(evento).to be_present
      expect(evento.registrado_en.to_date).to eq(Time.zone.today)
    end

    # El padre no se toca: sus plantas siguen en la bandeja.
    it 'el lote de origen sigue enraizando' do
      lote = lote_enraizando(plantas: 8)

      Lotes::Desprender.call(lote: lote, usuario: admin, cantidad: 5, tamanio_maceta: '0.5')

      expect(lote.reload.estado).to eq('enraizado')
    end

    it 'sin maceta nueva, el hijo hereda el estado del padre' do
      lote = lote_enraizando(plantas: 8)

      res = Lotes::Desprender.call(lote: lote, usuario: admin, cantidad: 5)

      expect(res.lote_nuevo.estado).to eq('enraizado')
    end
  end

  describe 'registrando un trasplante' do
    it 'sacar de la bandeja a maceta también prende el lote' do
      lote = lote_enraizando

      Lotes::RegistrarTrasplante.call(lote: lote, usuario: admin, destino: '1')

      expect(lote.reload.estado).to eq('vegetativo')
    end
  end
end
