require 'rails_helper'

# AC: el interruptor del panel manda. Si WhatsApp está apagado, la organización no manda —ni
# paga— mensajes de WhatsApp, aunque las credenciales de Twilio sigan cargadas.
#
# El bug: el servicio decidía el canal mirando sólo `twilio_configurado?`. A una organización a
# la que se le apagaba el add-on le seguían saliendo los avisos por WhatsApp, así que el
# interruptor no controlaba nada — y lo que se apaga es justo lo que se factura.
#
# Cómo se distingue el canal sin stubear a Twilio (no se usa `allow_any_instance_of`): el
# servicio manda por UNO de los dos caminos. Si sale por mail, hay una entrega en
# `ActionMailer::Base.deliveries`; si intenta WhatsApp, no la hay.
RSpec.describe NotificacionDeliveryService do
  # La casilla SMTP hace falta para que el camino del mail llegue a salir: sin ella
  # `mail_para_club` corta antes y los dos escenarios quedarían sin entrega, o sea sin poder
  # distinguirse. Es también el caso real que importa — la organización que tenía WhatsApp y lo
  # dio de baja sigue teniendo su correo conectado.
  let(:club) do
    create(:club, features: Club::FEATURES_POR_DEFECTO.merge('whatsapp' => whatsapp_contratado),
                  twilio_account_sid: 'AC' + ('0' * 32), twilio_auth_token: 'token-de-prueba',
                  twilio_whatsapp_from: '+5491100000000',
                  smtp_host: 'smtp.gmail.com', smtp_port: 587,
                  smtp_user: 'laorganizacion@gmail.com', smtp_pass: 'clave',
                  smtp_from: 'laorganizacion@gmail.com')
  end
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala) }
  let(:paciente) do
    create(:paciente, club: club, created_by: admin, telefono: '1155667788',
           email: 'paciente@test.com', domicilio_calle: 'Calle', domicilio_ciudad: 'CABA')
  end
  let(:stock) do
    Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca',
                  unidad: 'g', cantidad: 100, precio_sugerido_ars: 100)
  end
  # La `sede` no es opcional para este servicio: es de donde saca la organización
  # (`dispensacion.sede&.club`). Sin ella no hay club, y sin club no hay ni add-on que mirar ni
  # remitente para el mail — los dos caminos quedarían mudos y el spec pasaría por la razón
  # equivocada.
  let(:despacho) do
    Dispensacion.create!(paciente: paciente, user: admin, stock: stock, sede: sede, cantidad: 1,
                         medio_pago: 'efectivo', fecha_dispensacion: Date.current,
                         con_envio: true, direccion_envio: 'Av. Siempreviva 742',
                         contacto_nombre: 'Quien recibe', contacto_telefono: '1155667788')
  end

  around { |ex| ActsAsTenant.with_tenant(club) { ex.run } }
  before { ActionMailer::Base.deliveries.clear }

  context 'con el add-on de WhatsApp contratado' do
    let(:whatsapp_contratado) { true }

    it 'usa WhatsApp: no cae al mail' do
      expect(club.twilio_configurado?).to be(true)

      described_class.new(despacho).notificar_entrega

      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  context 'sin el add-on, con Twilio todavía cargado' do
    let(:whatsapp_contratado) { false }

    it 'no manda WhatsApp: el aviso sale por mail, que es el canal de siempre' do
      expect(club.twilio_configurado?).to be(true), 'el spec no probaría nada sin credenciales'

      described_class.new(despacho).notificar_entrega

      expect(ActionMailer::Base.deliveries.size).to eq(1)
      expect(ActionMailer::Base.deliveries.last.to).to eq(['paciente@test.com'])
    end
  end
end
