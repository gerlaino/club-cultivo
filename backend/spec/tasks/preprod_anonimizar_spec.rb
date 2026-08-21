require 'rails_helper'
require Rails.root.join('lib/preprod/anonimizador')

# AC: después de anonimizar, en la base NO queda un solo dato de una persona real — ni un nombre,
# ni un DNI, ni un mail, ni un domicilio, ni una línea de texto clínico. Y sobre todo: no queda
# ningún CANAL por el que preproducción pueda contactar a alguien.
#
# Este spec es lo que hace confiable el proceso. Sin él, "anonimizamos" es una promesa: alguien
# agrega una columna con un teléfono adentro y nadie se entera hasta que se filtra.
RSpec.describe Preprod::Anonimizador do
  let(:club) do
    create(:club, name: 'Club Real',
                  smtp_host: 'smtp.gmail.com', smtp_user: 'club@gmail.com', smtp_pass: 'clave-real',
                  twilio_account_sid: 'AC123', twilio_whatsapp_from: '+5491122223333')
  end
  let(:admin)  { create(:user, :admin, club: club, first_name: 'Germán', last_name: 'Laino', email: 'german@real.com') }
  let(:medico) { create(:user, :medico, club: club) }

  let!(:paciente) do
    ActsAsTenant.with_tenant(club) do
      create(:paciente, club: club, created_by: admin,
                        nombre: 'Mariana', apellido: 'Quiroga', dni: '28444555',
                        email: 'mariana.quiroga@gmail.com', telefono: '1155667788')
    end
  end

  before do
    ActsAsTenant.with_tenant(club) do
      create(:indicacion_medica, paciente: paciente, user: medico,
                                 patologia: 'Epilepsia refractaria', dosificacion: '5 gotas',
                                 observaciones: 'Consultar con la Dra. Pérez al 1144556677')
      create(:turno, paciente: paciente, medico: medico, club: club,
                     motivo: 'Dolor', notas_post: 'Refiere consumo problemático de alcohol')
      Webhook.create!(club: club, created_by: admin, nombre: 'ERP', url: 'https://erp-del-cliente.com/hook',
                      secret: 'secreto-real', events: ['dispensacion.creada'].to_json, active: true)
      PushSubscription.create!(user: admin, club: club, endpoint: 'https://fcm.googleapis.com/real',
                               p256dh_key: 'k', auth_key: 'a')
    end
  end

  # Se instancia derecho: el guard de `CONFIRMO_BASE` protege la línea de comandos, no la clase.
  def anonimizar! = described_class.new(simular: false).ejecutar!

  describe 'los canales hacia personas reales' do
    # Lo más peligroso de una copia de producción no son los datos: es que preproducción hereda la
    # casilla real de la organización y le puede mandar un mail a un paciente de verdad.
    it 'la casilla SMTP de la organización queda desconectada' do
      expect { anonimizar! }.to change { club.reload.smtp_pass }.to(nil)

      expect(club.smtp_host).to be_nil
      expect(club.smtp_user).to be_nil
      expect(club.smtp_configured?).to be(false)
    end

    it 'las credenciales de WhatsApp también' do
      anonimizar!

      expect(club.reload.twilio_account_sid).to be_nil
      expect(club.twilio_whatsapp_from).to be_nil
    end

    # Un webhook activo apuntando al ERP del cliente le mandaría eventos de prueba a su sistema.
    it 'los webhooks quedan apagados y sin la URL real' do
      anonimizar!

      wh = Webhook.unscoped.first
      expect(wh.active).to be(false)
      expect(wh.url).not_to include('erp-del-cliente')
      expect(wh.secret).not_to eq('secreto-real')
    end

    # Son tokens de celulares REALES: se borran, no se disfrazan.
    it 'las suscripciones push se borran' do
      expect { anonimizar! }.to change { PushSubscription.unscoped.count }.to(0)
    end
  end

  describe 'la identidad de las personas' do
    before { anonimizar! }

    it 'el paciente no conserva nombre, DNI, mail ni teléfono' do
      p = Paciente.unscoped.find(paciente.id)

      expect(p.nombre).not_to eq('Mariana')
      expect(p.apellido).not_to eq('Quiroga')
      expect(p.dni).not_to eq('28444555')
      expect(p.email).not_to include('gmail')
      expect(p.telefono).not_to eq('1155667788')
    end

    # Determinístico a partir del id: el mismo paciente es siempre el mismo entre dos corridas del
    # clon, así que un bug que se reproduce hoy se sigue reproduciendo mañana.
    it 'el reemplazo es estable y reconocible' do
      p = Paciente.unscoped.find(paciente.id)

      expect(p.apellido).to eq("N#{p.id}")
      expect(p.dni).to eq((90_000_000 + p.id).to_s)
    end

    it 'el operador tampoco conserva su nombre ni su mail' do
      u = User.unscoped.find(admin.id)

      expect(u.first_name).not_to eq('Germán')
      expect(u.email).not_to include('real.com')
      expect(u.email_personal).to be_nil
    end

    # El login del portal se deriva del nombre; romperle el formato dejaría cuentas inusables.
    it 'el mail del paciente conserva la FORMA, no el contenido' do
      cuenta = ActsAsTenant.with_tenant(club) { Pacientes::Acceso.crear!(paciente).user }
      described_class.new(simular: false).ejecutar!

      expect(User.unscoped.find(cuenta.id).email).to end_with('.paciente')
    end
  end

  describe 'el texto clínico y el escrito a mano' do
    before { anonimizar! }

    # Están ENCRIPTADOS con las claves de producción, así que se pisan en SQL sin leerlos: en
    # preprod las claves son otras y leerlos revienta.
    it 'la indicación médica no conserva la patología real' do
      fila = ActiveRecord::Base.connection.select_one('SELECT * FROM indicacion_medicas LIMIT 1')

      expect(fila['patologia']).not_to include('Epilepsia')
      expect(fila['observaciones']).to be_nil
    end

    it 'las notas del médico sobre el turno desaparecen' do
      expect(Turno.unscoped.first.notas_post).to be_nil
    end
  end

  # La red que atrapa lo que se agregue mañana: si alguien suma una columna con un teléfono
  # adentro, este barrido la encuentra sin que nadie se acuerde de actualizar el rake.
  describe 'el barrido final' do
    it 'ningún dato de la persona real sobrevive en ninguna tabla' do
      anonimizar!

      rastros = ['Mariana', 'Quiroga', '28444555', 'mariana.quiroga', '1155667788',
                 'Epilepsia refractaria', 'consumo problemático', 'clave-real',
                 'erp-del-cliente', 'secreto-real']

      encontrados = []
      ActiveRecord::Base.connection.tables.each do |tabla|
        next if tabla.start_with?('ar_internal', 'schema_')

        textuales = ActiveRecord::Base.connection.columns(tabla)
                                      .select { |c| %i[string text jsonb json].include?(c.type) }
                                      .map(&:name)
        next if textuales.empty?

        concat = textuales.map { |c| "COALESCE(#{ActiveRecord::Base.connection.quote_column_name(c)}::text, '')" }
                          .join(" || ' ' || ")
        rastros.each do |rastro|
          n = ActiveRecord::Base.connection.select_value(
            "SELECT COUNT(*) FROM #{tabla} WHERE (#{concat}) ILIKE #{ActiveRecord::Base.connection.quote("%#{rastro}%")}"
          ).to_i
          encontrados << "#{tabla} → #{rastro} (#{n})" if n.positive?
        end
      end

      expect(encontrados).to be_empty, "quedaron datos reales en la base:\n  #{encontrados.join("\n  ")}"
    end
  end
end
