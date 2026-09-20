require 'rails_helper'

# «Algo cambió»: cada modelo de dominio avisa por el canal de su organización después de cada
# commit, con un formato único, para que las pantallas abiertas se actualicen sin recargar.
RSpec.describe Transmite do
  include ActionCable::TestHelper

  let(:club)  { create(:club) }
  let(:sede)  { create(:sede, club: club) }
  let(:sala)  { create(:sala, club: club, sede: sede) }

  def ultimo_aviso(club)
    broadcasts("club_#{club.id}").map { |b| JSON.parse(b) }.last
  end

  it 'avisa creado, actualizado y borrado, con el recurso que el frontend conoce' do
    tarea = nil
    expect { tarea = create(:tarea, club: club, titulo: 'Regar') }.to have_broadcasted_to("club_#{club.id}")
    expect(ultimo_aviso(club)).to include('recurso' => 'tareas', 'accion' => 'creado', 'id' => tarea.id)

    tarea.update!(titulo: 'Regar bien')
    expect(ultimo_aviso(club)).to include('recurso' => 'tareas', 'accion' => 'actualizado', 'id' => tarea.id)

    tarea.destroy!
    expect(ultimo_aviso(club)).to include('recurso' => 'tareas', 'accion' => 'borrado', 'id' => tarea.id)
  end

  it 'el stock viaja con su sede, para que quien mira otra sede no re-pida' do
    stock = create(:stock, club: club, sede: sede)
    expect(ultimo_aviso(club)).to include('recurso' => 'stocks', 'sede_id' => sede.id, 'id' => stock.id)
  end

  it 'dice quién lo hizo, para que la pestaña que guardó no se re-pida a sí misma' do
    user = create(:user, :admin, club: club)
    Current.user = user
    create(:tarea, club: club)
    expect(ultimo_aviso(club)['por']).to eq(user.id)
  ensure
    Current.user = nil
  end

  it 'va SÓLO al canal de su organización' do
    otro = create(:club)
    expect { create(:tarea, club: club) }.not_to have_broadcasted_to("club_#{otro.id}")
  end

  it 'un cable caído no rompe el guardado' do
    allow(ActionCable.server).to receive(:broadcast).and_raise(Redis::CannotConnectError.new('sin redis'))
    expect { create(:tarea, club: club) }.not_to raise_error
  end
end
