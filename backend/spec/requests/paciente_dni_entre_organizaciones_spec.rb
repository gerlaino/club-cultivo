require 'rails_helper'

# AC: una persona que se va de una organización y entra a otra se puede dar de alta ahí, sin
# depender de que la primera la borre.
#
# El DNI era único en TODA la plataforma: se había leído el requisito del REPROCANN —una persona
# se registra con UN cultivador a la vez— como si fuera una restricción de nuestra base. Eso
# dejaba el alta de un cliente colgada de que otro cliente hiciera algo, que además no tiene
# forma de pedirle ni de saber a quién. Y el mensaje de error le confirmaba que ese DNI existe en
# otra organización: es un dato de salud de alguien que no es su paciente.
RSpec.describe 'DNI de paciente entre organizaciones', type: :request do
  include AuthHelpers

  let(:club_viejo) { create(:club) }
  let(:club_nuevo) { create(:club) }
  let(:admin_viejo) { create(:user, :admin, club: club_viejo) }
  let(:admin_nuevo) { create(:user, :admin, club: club_nuevo) }

  let(:dni) { '30123456' }

  def alta(dni_alta = dni)
    post '/api/pacientes', params: { paciente: {
      nombre: 'Ana', apellido: 'Pérez', dni: dni_alta, fecha_nacimiento: '1990-05-05'
    } }
  end

  it 'la otra organización puede darla de alta con el mismo DNI' do
    ActsAsTenant.with_tenant(club_viejo) do
      create(:paciente, club: club_viejo, dni: dni, created_by: admin_viejo)
    end

    sign_in_as(admin_nuevo)
    alta

    expect(response).to have_http_status(:created), response.body
    expect(Paciente.unscoped.where(club_id: club_nuevo.id).count).to eq(1)
  end

  it 'y no ve nada de la ficha de la otra: son dos pacientes distintos' do
    original = ActsAsTenant.with_tenant(club_viejo) do
      create(:paciente, club: club_viejo, dni: dni, created_by: admin_viejo,
                        telefono: '1122334455')
    end

    sign_in_as(admin_nuevo)
    alta
    nuevo_id = JSON.parse(response.body)['data']['id']

    expect(nuevo_id).not_to eq(original.id)
    expect(JSON.parse(response.body)['data']['telefono']).to be_blank
  end

  it 'dentro de la misma organización sigue sin poder repetirse' do
    sign_in_as(admin_nuevo)
    alta

    expect { alta }.not_to change(Paciente, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  # El mensaje no puede delatar que el DNI existe en otra organización: quien lo lee no es su
  # paciente.
  it 'el rechazo habla sólo de la organización de quien lo lee' do
    sign_in_as(admin_nuevo)
    alta
    alta

    error = JSON.parse(response.body)['errors'].join
    expect(error).to match(/esta organización/i)
    expect(error).not_to match(/otra organización|dos organizaciones|sistema/i)
  end
end
