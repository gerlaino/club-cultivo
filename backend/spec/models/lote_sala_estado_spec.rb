require 'rails_helper'

# AC: un lote en floración no puede estar en una sala de vegetativo, ni al revés. La regla
# vivía SÓLO en el filtro del modal de alta, así que editar el lote o moverlo de sala la
# salteaba sin decir nada.
RSpec.describe Lote, 'sala vs estado' do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin, tipo: 'produccion') }

  def sala!(kind) = create(:sala, sede: sede, club: club, kind: kind)
  def lote!(estado, sala) = build(:lote, club: club, sala: sala, estado: estado)

  it 'un lote en floración no entra en una sala de vegetativo' do
    l = lote!('floracion', sala!('vegetativo'))

    expect(l).not_to be_valid
    expect(l.errors[:sala].join).to match(/movelo a una sala de floracion/i)
  end

  it 'un lote en vegetativo no entra en una sala de floración' do
    expect(lote!('vegetativo', sala!('floracion'))).not_to be_valid
  end

  it 'la sala mixta acepta cualquiera de los dos' do
    mixta = sala!('mixta')

    expect(lote!('vegetativo', mixta)).to be_valid
    expect(lote!('floracion', mixta)).to be_valid
  end

  it 'el enraizado también puede estar en una sala de clones' do
    expect(lote!('enraizado', sala!('clon'))).to be_valid
  end

  # El agujero real: el lote se creaba bien y después se lo pasaba a floración sin moverlo.
  it 'no se puede avanzar a floración quedándose en la sala de vegetativo' do
    l = create(:lote, club: club, sala: sala!('vegetativo'), estado: 'vegetativo')

    l.estado = 'floracion'

    expect(l).not_to be_valid
  end

  # El otro agujero: mover el lote a una sala que no le corresponde.
  it 'no se puede mover un lote en floración a una sala de vegetativo' do
    l = create(:lote, club: club, sala: sala!('floracion'), estado: 'floracion')

    l.sala = sala!('vegetativo')

    expect(l).not_to be_valid
  end

  # Post-cosecha el lote suelta la sala: la regla no aplica.
  it 'no molesta a los lotes post-cosecha, que no tienen sala' do
    l = create(:lote, club: club, sala: sala!('floracion'), estado: 'floracion')

    l.assign_attributes(estado: 'cosecha', sala: nil)

    expect(l).to be_valid
  end

  # Si en producción quedó algún lote inconsistente de antes, no puede quedar trabado para
  # cualquier otra edición: la validación sólo corre cuando cambia la sala o el estado.
  it 'un lote inconsistente de antes se puede seguir editando en lo demás' do
    l = create(:lote, club: club, sala: sala!('floracion'), estado: 'floracion')
    l.update_columns(sala_id: sala!('vegetativo').id)

    l.reload.notes = 'una nota'

    expect(l).to be_valid
  end
end
