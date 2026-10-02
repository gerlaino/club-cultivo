require 'rails_helper'
require Rails.root.join('lib/club_backup').to_s

# AC (Germán, 2-oct-2026): «desde el super admin un panel donde veamos los servicios, los
# servidores… simple a la vista, que quien sea entienda lo que ve». Y los backups: cuándo fue el
# último y si sirve.
RSpec.describe 'Panel de Estado de la plataforma', type: :request do
  include AuthHelpers
  def json = JSON.parse(response.body)

  let(:club) { create(:club) }

  before { Rails.cache.clear }

  describe 'GET /super_admin/estado' do
    it 'el super admin lo ve: una frase, un semáforo y los avisos con qué hacer' do
      sign_in_as(create(:user, role: 'super_admin', club: nil))
      get '/super_admin/estado', headers: auth_headers

      expect(response).to have_http_status(:ok), response.body
      expect(json).to include('estado', 'frase', 'avisos', 'chequeos', 'backup', 'servidores', 'organizaciones', 'cola')
      expect(json['avisos']).to all(include('nivel', 'que', 'hacer'))
    end

    it 'sin la llave de Render lo dice como sugerencia, no como error' do
      sign_in_as(create(:user, role: 'super_admin', club: nil))
      get '/super_admin/estado', headers: auth_headers
      expect(json['servidores']).to include('configurado' => false)
      expect(json['avisos'].map { |a| a['que'] }).to include(a_string_including('Render'))
    end

    it 'un admin de organización no lo ve: es de la plataforma' do
      sign_in_as(create(:user, :admin, club: club))
      get '/super_admin/estado', headers: auth_headers
      expect(response).to have_http_status(:forbidden)
    end

    it 'sin sesión, no' do
      get '/super_admin/estado'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe Backups::Ultimo do
    ObjetoBackupFalso = Struct.new(:key, :last_modified, :size)

    def bucket_con(*horas_atras, verificacion: nil)
      objs = horas_atras.map { |h| ObjetoBackupFalso.new("postgres/b#{h}.dump", Time.current - h.hours, 10 * 1024 * 1024) }
      cli = Object.new
      cli.define_singleton_method(:list_objects_v2) { |**| Struct.new(:contents, :next_continuation_token, :is_truncated).new(objs, nil, false) }
      allow(ClubBackup).to receive_messages(configurado?: true, client: cli, bucket: 'b', bucket_compartido?: false)
      allow(ClubBackup).to receive(:leer_verificacion).and_return(verificacion)
    end

    it 'el de hoy corrió: verde' do
      bucket_con(5, 29)
      expect(described_class.call).to include(estado: 'ok', horas_desde: 5.0, total: 2)
    end

    it 'pasaron más de 26 horas: el de hoy no corrió, para mirar' do
      bucket_con(30)
      expect(described_class.call[:estado]).to eq('atencion')
    end

    it 'más de 48 horas: roto' do
      bucket_con(50)
      expect(described_class.call).to include(estado: 'mal', atrasado: true)
    end

    it 'el monitor externo recibe 503 cuando el de hoy no corrió' do
      bucket_con(30)
      get 'http://www.example.com/salud/backup'
      expect(response).to have_http_status(:service_unavailable)
      bucket_con(2)
      Rails.cache.clear
      get 'http://www.example.com/salud/backup'
      expect(response).to have_http_status(:ok)
    end
  end

  describe ClubBackup do
    LISTADO_DUMP_FALSO = <<~TXT.freeze
      ;
      ; Archive created at 2026-10-02 07:00:01 UTC
      ;
      215; 1259 16385 TABLE public pacientes postgres
      3401; 0 16385 TABLE DATA public pacientes postgres
      3402; 0 16390 TABLE DATA public clubs postgres
      3403; 0 16391 TABLE DATA public users postgres
      3404; 0 16392 TABLE DATA public dispensaciones postgres
      3405; 0 16393 TABLE DATA public stocks postgres
      3406; 0 16394 TABLE DATA public lotes postgres
    TXT

    it 'un dump con las tablas clave pasa la verificación' do
      v = ClubBackup.veredicto(ClubBackup.tablas_con_datos(LISTADO_DUMP_FALSO))
      expect(v).to include(ok: true, tablas: 6, faltan: [])
    end

    it 'si le falta una tabla clave, no pasa: el archivo está cortado o es de otra base' do
      v = ClubBackup.veredicto(ClubBackup.tablas_con_datos(LISTADO_DUMP_FALSO.sub(/.*dispensaciones.*\n/, '')))
      expect(v).to include(ok: false, faltan: ['dispensaciones'])
    end
  end
end
