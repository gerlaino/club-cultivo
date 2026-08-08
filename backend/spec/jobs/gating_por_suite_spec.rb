require 'rails_helper'

# Los jobs corren fuera de un request: no pasan por `check_club_activo!` ni por
# `require_feature!`. Antes de esto, un club que apagaba un módulo —o que se daba de baja—
# seguía recibiendo sus alertas y sus mails. El caso más caro: el aviso de vencimiento de
# REPROCANN le llega al PACIENTE, no al club.
RSpec.describe 'Jobs: gating por suite y por club operativo', type: :job do
  # Cada `sin(...)` devuelve un club igual al de la factory pero con esa clave apagada.
  def club_sin(*claves, **attrs)
    features = Club::FEATURES_POR_DEFECTO.dup
    claves.each { |c| features[c.to_s] = false }
    create(:club, features: features, **attrs)
  end

  # Spec multi-club: no hay `let(:club)`, así que el hook de spec/support/tenant.rb no fija
  # tenant y con require_tenant=true cualquier consulta explota. Se consulta sin tenant y se
  # filtra por club_id a mano, que es justo lo que se quiere verificar.
  def alertas(club, tipo)
    ActsAsTenant.without_tenant { AlertaInterna.where(club_id: club.id, tipo: tipo).count }
  end

  def alertas_totales(club)
    ActsAsTenant.without_tenant { AlertaInterna.where(club_id: club.id).count }
  end

  describe StockBajoJob do
    def con_flor_baja(club)
      ActsAsTenant.with_tenant(club) do
        admin = create(:user, :admin, club: club)
        sede  = create(:sede, club: club, created_by: admin)
        create(:stock, :externo, club: club, sede: sede,
               forma_producto: 'flor_seca', cantidad: 1, estado: 'asignado')
      end
    end

    it 'alerta al club que tiene Producción y dispensa' do
      club = create(:club, umbral_stock_g: 100)
      con_flor_baja(club)
      expect { described_class.perform_now }.to change { alertas(club, 'stock_bajo') }.by(1)
    end

    it 'NO alerta al club que apagó Producción y dispensa' do
      club = club_sin(:produccion_dispensa, umbral_stock_g: 100)
      con_flor_baja(club)
      expect { described_class.perform_now }.not_to change { alertas(club, 'stock_bajo') }
    end

    it 'NO alerta al club SUSPENDIDO, que `Club.activos` sí devolvía' do
      club = create(:club, umbral_stock_g: 100)
      con_flor_baja(club)
      club.suspender!
      expect { described_class.perform_now }.not_to change { alertas(club, 'stock_bajo') }
    end

    it 'NO alerta al club ELIMINADO' do
      club = create(:club, umbral_stock_g: 100)
      con_flor_baja(club)
      club.update!(deleted_at: Time.current)
      expect { described_class.perform_now }.not_to change { alertas(club, 'stock_bajo') }
    end
  end

  describe ReprocannVencimientoJob do
    def con_reprocann_vencido(club)
      ActsAsTenant.with_tenant(club) do
        create(:paciente, club: club, es_paciente: true,
               reprocann_estado: 'activo', reprocann_vencimiento: 3.days.ago.to_date)
      end
    end

    it 'alerta al club que tiene Producción y dispensa' do
      club = create(:club)
      con_reprocann_vencido(club)
      expect { described_class.perform_now }
        .to change { alertas_totales(club) }.by_at_least(1)
    end

    it 'NO alerta al club que apagó Producción y dispensa' do
      club = club_sin(:produccion_dispensa)
      con_reprocann_vencido(club)
      expect { described_class.perform_now }
        .not_to change { alertas_totales(club) }
    end
  end

  describe AsignacionPostcosechaJob do
    def con_lote_cosechado(club)
      ActsAsTenant.with_tenant(club) do
        club.update!(alertas_config: { 'postcosecha_dias' => 1, 'postcosecha_modo' => 'avisar' })
        admin = create(:user, :admin, club: club)
        lote  = create(:lote, club: club, estado: 'cosecha')
        lote.lote_eventos.create!(tipo: 'cambio_estado', estado_nuevo: 'cosecha',
                                  registrado_en: 5.days.ago, user: admin, club: club)
        lote
      end
    end

    it 'avisa al club que tiene Cultivo' do
      club = create(:club)
      con_lote_cosechado(club)
      expect { described_class.perform_now }
        .to change { alertas_totales(club) }.by_at_least(1)
    end

    it 'NO avisa al club que apagó Cultivo' do
      club = club_sin(:cultivo)
      con_lote_cosechado(club)
      expect { described_class.perform_now }
        .not_to change { alertas_totales(club) }
    end
  end

  describe InformeSemestralJob do
    # El mailer necesita un admin con email: sin destinatario no manda nada y el spec pasaría
    # en verde por el motivo equivocado.
    def con_admin(club)
      ActsAsTenant.with_tenant(club) { create(:user, :admin, club: club) }
      club
    end

    # Se espía el mailer en vez de contar deliveries: el envío real exige que el club tenga
    # SMTP propio configurado (`ApplicationMailer#mail_para_club`), que es una condición
    # aparte de la que se está probando acá.
    let(:entrega) { double('mail', deliver_now: true) }

    it 'le arma el informe al club que tiene al menos una de las dos suites' do
      club = con_admin(create(:club, email: 'con@suite.test'))
      expect(NotificacionesMailer).to receive(:informe_semestral)
        .with(hash_including(club: club)).and_return(entrega)

      described_class.perform_now(:envio)
    end

    it 'NO le arma el informe al club sin ninguna de las dos suites' do
      con_admin(club_sin(:cultivo, :produccion_dispensa, email: 'sin@suite.test'))
      expect(NotificacionesMailer).not_to receive(:informe_semestral)

      described_class.perform_now(:envio)
    end

    it 'NO le arma el informe al club suspendido' do
      con_admin(create(:club, email: 'suspendido@test.test')).suspender!
      expect(NotificacionesMailer).not_to receive(:informe_semestral)

      described_class.perform_now(:envio)
    end
  end
end
