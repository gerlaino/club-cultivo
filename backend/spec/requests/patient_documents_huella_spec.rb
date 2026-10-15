require 'rails_helper'

# Producción, 15-oct-2026: «Subir documento» → «Error en el servidor». La huella del documento se
# calculaba sobre el texto y todo archivo subido tiene el mismo, «(documento adjunto)»: el primer
# archivo de la plataforma se guardó y todos los siguientes chocaban con el índice único
# (PG::UniqueViolation en `index_patient_documents_on_hash_documento`). En los specs nunca se vio
# porque cada test sube «el primer archivo».
RSpec.describe 'Documentos de paciente: subir archivos', type: :request do
  let(:club)  { create(:club, features: { 'produccion_dispensa' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:ana)   { ActsAsTenant.with_tenant(club) { create(:paciente, club: club, created_by: admin) } }
  let(:beto)  { ActsAsTenant.with_tenant(club) { create(:paciente, club: club, created_by: admin) } }

  before { sign_in_as(admin) }

  def pdf(contenido, nombre = 'Documento.pdf')
    Rack::Test::UploadedFile.new(StringIO.new(contenido), 'application/pdf', original_filename: nombre)
  end

  def subir(paciente, contenido, tipo: 'historia_clinica')
    post "/api/pacientes/#{paciente.id}/documents",
         params: { document: { nombre: 'Historia Clinica', tipo: tipo }, archivo_pdf: pdf(contenido) }
    response
  end

  it 'se suben varios archivos distintos, uno detrás de otro' do
    expect(subir(ana, "%PDF-1.4 historia\n")).to have_http_status(:created)
    expect(subir(ana, "%PDF-1.4 reprocann\n", tipo: 'reprocann')).to have_http_status(:created)
    expect(subir(beto, "%PDF-1.4 estudio\n", tipo: 'estudio_clinico')).to have_http_status(:created)
    expect(ActsAsTenant.with_tenant(club) { PatientDocument.count }).to eq(3)
  end

  it 'el mismo archivo se puede subir a dos pacientes' do
    expect(subir(ana, "%PDF-1.4 mismo\n")).to have_http_status(:created)
    expect(subir(beto, "%PDF-1.4 mismo\n")).to have_http_status(:created)
  end

  it 'se puede volver a subir un archivo después de borrarlo' do
    subir(ana, "%PDF-1.4 otra vez\n")
    delete "/api/pacientes/#{ana.id}/documents/#{response.parsed_body['id']}"
    expect(subir(ana, "%PDF-1.4 otra vez\n")).to have_http_status(:created)
  end

  it 'la huella es la del archivo, no la del texto «(documento adjunto)»' do
    contenido = "%PDF-1.4 huella\n"
    subir(ana, contenido)
    expect(response.parsed_body['hash_documento']).to eq(Digest::SHA256.hexdigest(contenido))
  end

  it 'un documento escrito sigue teniendo la huella de su texto' do
    post "/api/pacientes/#{ana.id}/documents",
         params: { document: { nombre: 'Consentimiento', tipo: 'consentimiento', contenido_html: '<p>Acepto</p>' } }
    expect(response).to have_http_status(:created)
    expect(response.parsed_body['hash_documento']).to eq(Digest::SHA256.hexdigest('<p>Acepto</p>'))
  end
end
