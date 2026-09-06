require 'rails_helper'

# LA CAJA QUE QUEDÓ ABIERTA.
#
# Se cierra a la noche, y a la noche el admin no está: si alguien se fue sin cerrar, nadie se
# entera hasta la mañana siguiente —cuando el que abre no puede arrancar, porque ya hay una caja
# abierta— y para entonces el arqueo de esa jornada ya no lo puede hacer nadie.
RSpec.describe CierreMostradorPendienteJob do
  let(:club)  { create(:club, features: { 'produccion_dispensa' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:ana)   { create(:user, :dispensador, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'social', nombre: 'Centro') }

  def configurar!(activo: true, hora: '23:00', por_sede: {})
    club.update!(alertas_config: club.alertas_config.merge(
      'cierre_mostrador' => { 'activo' => activo, 'hora' => hora, 'por_sede' => por_sede }
    ))
  end

  def abrir!(a_las: nil)
    ActsAsTenant.with_tenant(club) do
      t = Mostradores::AbrirCaja.call(mostrador: sede.mostrador!, usuario: ana,
                                      efectivo_contado_ars: 0).turno
      t.update_columns(abierto_at: a_las) if a_las
      t
    end
  end

  def alertas = AlertaInterna.unscoped.where(club_id: club.id, tipo: 'cierre_mostrador_pendiente')

  # Las 23:30 de hoy: pasada la hora límite configurada.
  def a_las(hora, min = 0) = Time.zone.now.change(hour: hora, min: min)

  describe 'cuando la caja sigue abierta pasada la hora' do
    before { configurar!(hora: '23:00') }

    it 'avisa una vez, diciendo qué caja y desde cuándo' do
      abrir!(a_las: a_las(9, 5))

      travel_to(a_las(23, 30)) do
        expect { described_class.new.perform }.to change { alertas.count }.by(1)
      end

      a = alertas.last
      expect(a.mensaje).to include('Centro')
      expect(a.mensaje).to include('09:05')
      expect(a.destinada_a_role).to eq('admin')
      expect(a.contexto['sede_id']).to eq(sede.id)
    end

    # Cada quince minutos es cómo se aprende a ignorarlo.
    it 'y no lo repite en el mismo día' do
      abrir!(a_las: a_las(9, 5))

      travel_to(a_las(23, 30)) do
        described_class.new.perform
        expect { described_class.new.perform }.not_to change { alertas.count }
      end
    end
  end

  describe 'cuando no hay nada que avisar' do
    before { configurar!(hora: '23:00') }

    it 'antes de la hora no avisa' do
      abrir!(a_las: a_las(9, 5))

      travel_to(a_las(22, 45)) do
        expect { described_class.new.perform }.not_to change { alertas.count }
      end
    end

    it 'con la caja cerrada tampoco: no hay nada abierto' do
      travel_to(a_las(23, 30)) do
        expect { described_class.new.perform }.not_to change { alertas.count }
      end
    end

    # Una caja abierta DESPUÉS de la hora no es una caja olvidada: es el turno que empieza.
    it 'una caja abierta pasada la hora no dispara el aviso al minuto' do
      abrir!(a_las: a_las(23, 20))

      travel_to(a_las(23, 30)) do
        expect { described_class.new.perform }.not_to change { alertas.count }
      end
    end

    it 'con la alerta apagada no avisa aunque quede abierta toda la noche' do
      configurar!(activo: false)
      abrir!(a_las: a_las(9, 5))

      travel_to(a_las(23, 59)) do
        expect { described_class.new.perform }.not_to change { alertas.count }
      end
    end

    it 'sin configurar nada, tampoco: no avisar es el estado por defecto' do
      club.update!(alertas_config: {})
      abrir!(a_las: a_las(9, 5))

      travel_to(a_las(23, 59)) do
        expect { described_class.new.perform }.not_to change { alertas.count }
      end
    end

    it 'y una organización sin Producción y dispensa queda afuera' do
      club.update!(features: { 'produccion_dispensa' => false })
      abrir!(a_las: a_las(9, 5))

      travel_to(a_las(23, 30)) do
        expect { described_class.new.perform }.not_to change { alertas.count }
      end
    end
  end

  # Una organización con dos sedes puede cerrar a horas distintas, y es justo donde más sirve:
  # el admin no está en ninguna de las dos.
  describe 'la excepción por sede' do
    it 'manda sobre la general' do
      configurar!(hora: '23:00', por_sede: { sede.id.to_s => '21:00' })
      abrir!(a_las: a_las(9, 5))

      travel_to(a_las(21, 30)) do
        expect { described_class.new.perform }.to change { alertas.count }.by(1)
      end
    end

    it 'y una excepción vacía vuelve a la general' do
      configurar!(hora: '23:00', por_sede: { sede.id.to_s => '' })
      abrir!(a_las: a_las(9, 5))

      travel_to(a_las(21, 30)) do
        expect { described_class.new.perform }.not_to change { alertas.count }
      end
      travel_to(a_las(23, 30)) do
        expect { described_class.new.perform }.to change { alertas.count }.by(1)
      end
    end
  end
end
