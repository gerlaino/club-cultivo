require 'rails_helper'

# El aviso de merma no tiene umbral fijo, y es a propósito: un 3% puede ser normal fraccionando
# flor y un escándalo en aceite. Lo que importa no es el número sino que CAMBIÓ respecto del
# patrón de esa misma organización.
#
# Y no acusa a nadie: dice "acá cambió algo, andá a mirar".
RSpec.describe MermaMostradorJob do
  let(:club)  { create(:club, features: { 'produccion_dispensa' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:ana)   { create(:user, :dispensador, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'social', nombre: 'Centro') }
  let(:lote)  { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }

  let!(:stock) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 100_000, estado: 'asignado', disponibilidad: 'ambas',
                     costo_unitario_ars: 100, precio_sugerido_ars: 500)
    end
  end

  # Un turno cerrado con lo dispensado y el faltante que se le indique, fechado cuando haga falta.
  def turno!(dispensado:, faltante:, cuando: Time.current)
    ActsAsTenant.with_tenant(club) do
      mostrador = sede.mostrador!
      Mostradores::Cargar.call(mostrador: mostrador, usuario: admin, motivo: 'carga',
                               cambios: [{ stock_id: stock.id, cantidad: dispensado + 100 }])
      t = Mostradores::AbrirCaja.call(mostrador: mostrador, usuario: ana,
                                      efectivo_contado_ars: 0).turno
      # Se simula la jornada: salió `dispensado` y al contar faltan `faltante`.
      mi = mostrador.items.find_by(stock_id: stock.id)
      mi.mover!(cantidad: -dispensado, tipo: 'dispensa', usuario: ana, turno: t)
      t.items.find_by(stock_id: stock.id).imputar_dispensa!(dispensado)

      Mostradores::CerrarCaja.call(turno: t, usuario: ana, efectivo_contado_ars: 0,
                                   conteos: [{ stock_id: stock.id, contado: mi.reload.cantidad - faltante }],
                                   notas: 'merma')
      t.reload.update_columns(cerrado_at: cuando)
      # La mesa vuelve a cargarse en el próximo turno: cada uno arranca de cero para que los
      # ocho turnos del patrón sean comparables.
      Mostradores::Cargar.call(mostrador: mostrador, usuario: admin, motivo: 'reset',
                               cambios: [{ stock_id: stock.id, cantidad: 0 }])
      t
    end
  end

  def alertas = AlertaInterna.unscoped.where(club_id: club.id, tipo: 'merma_mostrador')

  # El mail sale de la casilla de la organización: sin el add-on Y sin casilla conectada no hay
  # de dónde mandarlo, y `mail_para_club` no manda nada.
  def conectar_casilla!
    club.update!(features: club.features.merge('mailer' => true),
                 smtp_host: 'smtp.gmail.com', smtp_port: 587, smtp_user: 'org@gmail.com',
                 smtp_pass: 'app-pass', smtp_from: 'org@gmail.com', smtp_from_name: 'Org')
    admin.update!(email: 'admin@org.com')
  end

  describe 'cuando la merma se dispara' do
    before do
      # Ocho semanas tranquilas: 0,5%.
      8.times { |i| turno!(dispensado: 1_000, faltante: 5, cuando: (14 + i * 5).days.ago) }
      # Y esta semana, 5%.
      turno!(dispensado: 1_000, faltante: 50, cuando: 1.day.ago)
    end

    it 'avisa, diciendo contra qué cambió' do
      expect { described_class.new.perform }.to change { alertas.count }.by(1)

      a = alertas.last
      expect(a.mensaje).to include('Centro')
      expect(a.severidad).to eq('warning')
      expect(a.destinada_a_role).to eq('admin')
      expect(a.contexto['sede_id']).to eq(sede.id)
    end

    # Repetirlo todos los días es cómo se aprende a ignorarlo.
    # La campana la mira quien entra a la app, y el admin de una organización chica puede no
    # entrar en toda la semana — que es justo cuando esto importa.
    it 'también manda el mail, si la organización tiene correo' do
      conectar_casilla!

      expect { described_class.new.perform }
        .to change { ActionMailer::Base.deliveries.size }.by(1)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.subject).to match(/merma/i)
      expect(mail.body.encoded).to include('Centro')
      # No acusa a nadie: la merma es inevitable y esto dice "andá a mirar".
      expect(mail.body.encoded).not_to match(/robo|falta.{0,10}alguien|responsable/i)
    end

    it 'sin el módulo de correo, la alerta interna alcanza' do
      expect { described_class.new.perform }
        .to change { alertas.count }.by(1)
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    # Si la casilla del cliente está mal configurada, el aviso interno igual tiene que quedar:
    # que no salga un mail no es motivo para perder la alerta.
    it 'y si el mail no sale, no se lleva puesta la alerta' do
      conectar_casilla!
      allow(NotificacionesMailer).to receive(:merma_mostrador).and_raise(Net::SMTPAuthenticationError, 'no')

      expect { described_class.new.perform }.to change { alertas.count }.by(1)
    end

    it 'no lo repite al día siguiente' do
      described_class.new.perform

      expect { described_class.new.perform }.not_to change { alertas.count }
    end
  end

  it 'con la merma estable no dice nada' do
    9.times { |i| turno!(dispensado: 1_000, faltante: 5, cuando: (1 + i * 6).days.ago) }

    expect { described_class.new.perform }.not_to change { alertas.count }
  end

  # Sin historia, "cambió" no significa nada: con dos turnos cualquier diferencia parece un salto.
  it 'sin semanas previas suficientes, se calla' do
    turno!(dispensado: 1_000, faltante: 50, cuando: 1.day.ago)
    2.times { |i| turno!(dispensado: 1_000, faltante: 5, cuando: (20 + i).days.ago) }

    expect { described_class.new.perform }.not_to change { alertas.count }
  end

  # 2 g sobre 10 dispensados es 20% y no dice nada.
  it 'con poco volumen esta semana, se calla' do
    8.times { |i| turno!(dispensado: 1_000, faltante: 5, cuando: (14 + i * 5).days.ago) }
    turno!(dispensado: 50, faltante: 10, cuando: 1.day.ago)

    expect { described_class.new.perform }.not_to change { alertas.count }
  end
end
