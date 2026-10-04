require 'rails_helper'

# AC (Germán, 4-oct-2026): desde la bandeja de Consultas el super admin le contesta a quien escribió.
# Sale por el correo de la plataforma, queda guardada como historial, la consulta pasa a atendida y
# la bandeja dice si la respuesta salió o no.
RSpec.describe 'Responder una consulta', type: :request do
  include ActiveJob::TestHelper

  let!(:super_admin) { create(:user, :super_admin, first_name: 'Germán') }
  let!(:consulta) do
    SolicitudContacto.create!(tipo: 'organizacion', nombre: 'Ana', email: 'ana@ong.org', mensaje: 'Somos 80 pacientes')
  end

  it 'guarda la respuesta, marca la consulta atendida y encola el envío' do
    sign_in_as(super_admin)
    expect {
      post "/api/super_admin/consultas/#{consulta.id}/respuestas", params: { texto: 'Hola Ana, te llamo mañana.' }, as: :json
    }.to change(ConsultaRespuesta, :count).by(1).and have_enqueued_job(EnviarRespuestaConsultaJob)
    expect(response).to have_http_status(:created)
    expect(consulta.reload.atendida_at).to be_present
    expect(response.parsed_body['respuestas'].first).to include('texto' => 'Hola Ana, te llamo mañana.', 'enviada_at' => nil)
  end

  it 'una respuesta vacía no se guarda' do
    sign_in_as(super_admin)
    post "/api/super_admin/consultas/#{consulta.id}/respuestas", params: { texto: '  ' }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(ConsultaRespuesta.count).to eq(0)
  end

  it 'el admin de una organización no puede responder' do
    club = create(:club)
    sign_in_as(create(:user, :admin, club: club))
    post "/api/super_admin/consultas/#{consulta.id}/respuestas", params: { texto: 'x' }, as: :json
    expect(response).to have_http_status(:forbidden)
    expect(ConsultaRespuesta.count).to eq(0)
  end

  describe 'el envío' do
    let!(:r) { consulta.respuestas.create!(autor: super_admin, texto: 'Hola Ana, te llamo mañana.') }

    it 'le llega SÓLO a quien escribió, con su código, y anota que salió' do
      expect { EnviarRespuestaConsultaJob.perform_now(r.id) }.to change { ActionMailer::Base.deliveries.size }.by(1)
      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq(['ana@ong.org'])
      expect(mail.cc).to be_blank
      expect(mail.bcc).to be_blank
      expect(mail.subject).to include(consulta.codigo)
      expect(mail.text_part.body.to_s).to include('te llamo mañana')
      expect(r.reload.enviada_at).to be_present
    end

    it 'si el correo falla, anota el error y no la da por enviada' do
      falla = instance_double(ActionMailer::MessageDelivery)
      allow(falla).to receive(:deliver_now).and_raise(Net::SMTPAuthenticationError.new('535 auth'))
      allow(AccesoMailer).to receive(:respuesta_consulta).and_return(falla)
      expect { EnviarRespuestaConsultaJob.perform_now(r.id) }.to raise_error(Net::SMTPAuthenticationError)
      expect(r.reload.enviada_at).to be_nil
      expect(r.error).to include('535')
    end
  end
end
