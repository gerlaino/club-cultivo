require 'rails_helper'

# AC: la franja de arriba sólo aparece cuando hay algo que decir.
#
# Una franja que dice algo siempre se deja de leer a la semana. Y el aviso que más importa —el
# único que el portal da y ninguna otra pantalla— es que el REPROCANN se vence ANTES de vencerse:
# vencido, el paciente no puede retirar, y el trámite de renovación lleva semanas.
RSpec.describe 'Portal — lo que hay que avisarle al paciente', type: :request do
  include AuthHelpers

  let(:club) { create(:club, vista_paciente_activa: true,
                  features: { 'produccion_dispensa' => true, 'vista_paciente' => true }) }
  let(:admin) { create(:user, :admin, club: club) }

  def paciente!(**attrs)
    ActsAsTenant.with_tenant(club) { create(:paciente, club: club, created_by: admin, **attrs) }
  end

  def entrar_como(paciente)
    user = ActsAsTenant.with_tenant(club) do
      u = Pacientes::Acceso.crear!(paciente).user
      u.update!(password: AuthHelpers::DEFAULT_PASSWORD, password_confirmation: AuthHelpers::DEFAULT_PASSWORD)
      u
    end
    sign_in_as(user)
    get '/api/portal/mi_estado'
    JSON.parse(response.body)['data']
  end

  describe 'el REPROCANN' do
    it 'con el trámite vigente y lejos, no avisa nada: es el estado normal' do
      datos = entrar_como(paciente!(reprocann_estado: 'activo', reprocann_numero: 'RP-1',
                                    reprocann_vencimiento: 6.months.from_now.to_date))

      expect(datos['avisos']).to be_empty
    end

    it 'a 24 días avisa cuántos faltan, que es lo que hace falta para arrancar el trámite' do
      datos = entrar_como(paciente!(reprocann_estado: 'activo', reprocann_numero: 'RP-1',
                                    reprocann_vencimiento: 24.days.from_now.to_date))

      aviso = datos['avisos'].find { |a| a['tipo'] == 'reprocann_por_vencer' }
      expect(aviso['dias']).to eq(24)
      expect(aviso['texto']).to include('24 días')
      expect(aviso['nivel']).to eq('atencion')
    end

    it 'vencido lo dice con lo que le cambia: no puede retirar' do
      datos = entrar_como(paciente!(reprocann_estado: 'activo', reprocann_numero: 'RP-1',
                                    reprocann_vencimiento: 2.days.ago.to_date))

      aviso = datos['avisos'].find { |a| a['tipo'] == 'reprocann_vencido' }
      expect(aviso['nivel']).to eq('urgente')
      expect(aviso['texto']).to include('no podés retirar')
    end

    it 'sin trámite iniciado también avisa: es lo que lo separa de poder retirar' do
      datos = entrar_como(paciente!(reprocann_estado: 'sin_registro'))

      expect(datos['avisos'].map { |a| a['tipo'] }).to include('reprocann_sin_registro')
    end
  end

  describe 'la cuenta corriente' do
    let(:paciente) { paciente!(reprocann_estado: 'activo', reprocann_numero: 'RP-1', reprocann_vencimiento: 1.year.from_now.to_date) }

    it 'avisa si debe' do
      ActsAsTenant.with_tenant(club) do
        CuentaCorriente.create!(paciente: paciente, club: club, limite_credito: 10_000, saldo_disponible: -3_200)
      end

      aviso = entrar_como(paciente)['avisos'].find { |a| a['tipo'] == 'saldo_pendiente' }
      expect(aviso['monto']).to eq(3200.0)
    end

    # Tener plata a favor no es algo que haya que avisar arriba de todo.
    it 'NO avisa si tiene saldo a favor' do
      ActsAsTenant.with_tenant(club) do
        CuentaCorriente.create!(paciente: paciente, club: club, limite_credito: 10_000, saldo_disponible: 5_000)
      end

      expect(entrar_como(paciente)['avisos']).to be_empty
    end
  end

  it 'manda el token del carnet, para poder mostrarlo en el mostrador sin buscarlo' do
    datos = entrar_como(paciente!(reprocann_estado: 'activo', reprocann_numero: 'RP-1',
                                  reprocann_vencimiento: 1.year.from_now.to_date))

    expect(datos['carnet_token']).to be_present
  end

  # ── La credencial ────────────────────────────────────────────────────────────────────────────
  #
  # Es lo primero del inicio y lo que el paciente muestra en la puerta. Hasta hoy vivía sólo en
  # `/c/:token` —un link que le mandaron una vez— y el portal no la mostraba en ningún lado.
  describe 'la credencial' do
    # ¿Puede retirar? Lo contesta lo que `Dispensacion` valida DE VERDAD sobre la persona: que
    # esté activa en la organización y aprobada. El REPROCANN no está entre esas validaciones.
    #
    # La credencial lo usaba igual para contestar, y mentía en los dos sentidos: al vencido le
    # decía que no podía cuando sí podía, y a uno vigente pero dado de baja le decía que sí y lo
    # rebotaban en la puerta. Estos cuatro casos son la matriz entera.
    describe '¿puede retirar?' do
      it 'activo y aprobado: sí' do
        c = entrar_como(paciente!(reprocann_estado: 'activo', reprocann_numero: 'RP-1'))['credencial']

        expect(c['puede_retirar']).to be(true)
        expect(c['motivo_bloqueo']).to be_nil
      end

      it 'con el REPROCANN vencido: SÍ, porque hoy nada lo bloquea' do
        c = entrar_como(paciente!(reprocann_estado: 'activo', reprocann_numero: 'RP-2',
                                  reprocann_vencimiento: 40.days.ago.to_date))['credencial']

        expect(c['puede_retirar']).to be(true)
        expect(c['reprocann_categoria']).to eq('vencido')
      end

      # Al dado de baja no le llega a aparecer la credencial: `check_rol_habilitado!` lo frena en
      # el login y en cada request, así que ni entra. El caso queda contemplado igual en
      # `motivo_bloqueo` porque `puede_retirar` espeja las validaciones de `Dispensacion` una a
      # una, y `es_paciente?` es una de ellas — pero la barrera de verdad es anterior.
      it 'dado de baja no entra al portal siquiera' do
        ficha = paciente!(reprocann_estado: 'activo', reprocann_numero: 'RP-3',
                          reprocann_vencimiento: 8.months.from_now.to_date)
        user = ActsAsTenant.with_tenant(club) do
          u = Pacientes::Acceso.crear!(ficha).user
          u.update!(password: AuthHelpers::DEFAULT_PASSWORD, password_confirmation: AuthHelpers::DEFAULT_PASSWORD)
          ficha.update!(es_paciente: false)
          u
        end

        post '/api/users/sign_in',
             params: { user: { email: user.email, password: AuthHelpers::DEFAULT_PASSWORD } }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(response.body).to include('dada de baja')
      end

      it 'pendiente de aprobación: no, y lo distingue de una baja' do
        ficha = paciente!(reprocann_estado: 'activo', reprocann_numero: 'RP-4')
        ActsAsTenant.with_tenant(club) { ficha.update!(aprobado_at: nil) }

        c = entrar_como(ficha)['credencial']

        expect(c['puede_retirar']).to be(false)
        expect(c['motivo_bloqueo']).to eq('pendiente')
      end

      # Si mañana el REPROCANN pasa a bloquear, el cambio va en `Dispensacion` y la credencial lo
      # refleja sola. Este test es el que avisa que hay que venir a actualizar el de arriba.
      it 'el backend NO exige REPROCANN para dispensar: si esto cambia, la credencial también' do
        validaciones = Dispensacion.validators.grep(ActiveModel::Validations::WithValidator)
                                   .flat_map { |v| Array(v.options[:with]) }

        expect(Dispensacion.instance_methods(false).grep(/reprocann/)).to be_empty
        expect(validaciones.map(&:to_s).grep(/reprocann/)).to be_empty
      end
    end

    it 'trae sus datos completos: acá está detrás de SU login, no es el carnet que reparte' do
      c = entrar_como(paciente!(nombre: 'Juan', apellido: 'Gómez', dni: '30111222',
                                reprocann_estado: 'activo', reprocann_numero: 'RP-9',
                                reprocann_vencimiento: 8.months.from_now.to_date))['credencial']

      # El endpoint público `/c/:token` manda "G." a propósito y ningún documento: es un link que
      # la persona entrega. Este es su portal y ve lo suyo entero.
      expect(c['apellido']).to eq('Gómez')
      expect(c['dni']).to eq('30111222')
      expect(c['reprocann_numero']).to eq('RP-9')
    end

    # Que la tarjeta del paciente y el informe del auditor no puedan discrepar es el punto de
    # reusar `Paciente.reprocann_categoria` en vez de recalcular acá.
    it 'clasifica igual que el informe REPROCANN' do
      vigente = entrar_como(paciente!(reprocann_estado: 'activo', reprocann_numero: 'RP-1',
                                      reprocann_vencimiento: 6.months.from_now.to_date))
      expect(vigente['credencial']['reprocann_categoria']).to eq('vigente')

      vencido = entrar_como(paciente!(dni: '38222111', reprocann_estado: 'activo', reprocann_numero: 'RP-2',
                                      reprocann_vencimiento: 3.days.ago.to_date))
      expect(vencido['credencial']['reprocann_categoria']).to eq('vencido')

      cerca = entrar_como(paciente!(dni: '38222333', reprocann_estado: 'activo', reprocann_numero: 'RP-3',
                                    reprocann_vencimiento: 10.days.from_now.to_date))
      expect(cerca['credencial']['reprocann_categoria']).to eq('por_vencer')
      expect(cerca['credencial']['dias_para_vencer']).to eq(10)
    end

    it 'trae el token del carnet: es el QR que le escanean en la puerta' do
      p = paciente!(reprocann_estado: 'activo', reprocann_numero: 'RP-1')

      expect(entrar_como(p)['credencial']['carnet_token']).to eq(p.reload.carnet_token)
    end
  end
end
