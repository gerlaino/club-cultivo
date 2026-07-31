require 'rails_helper'

# El enraizado es el OPUESTO del vegetativo, no una versión temprana. Antes el detector mandaba
# germinación y esqueje a los setpoints de vegetativo, y eso lo dejaba ciego para el problema real
# (aire seco que deshidrata los esquejes) mientras gritaba por uno inexistente (EC baja, que en un
# clonador es lo correcto). Estos specs fijan que cada fase se mida con su propia vara.
RSpec.describe AlertaDetectorService do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }

  # Spec de servicio: no hay login que fije el tenant, y con require_tenant=true (TEN-01c) crear
  # cualquier modelo de dominio sin tenant explota. `around` cubre también el setup de los `let`,
  # que es lo que un `before` deja afuera.
  around { |ex| ActsAsTenant.with_tenant(club) { ex.run } }

  def registrar(lote, veces: 3, **valores)
    veces.times do |i|
      create(:registro_ambiental, lote: lote, club: club, user: admin,
                                  registrado_en: (i + 1).hours.ago, **valores)
    end
  end

  def alertas(tipo: nil)
    detectar
    scope = club.alertas_internas
    tipo ? scope.where(tipo: tipo) : scope
  end

  def detectar = described_class.new(club).detectar!

  describe 'humedad: el caso que motivó el cambio' do
    # 60% es cómodo para vegetativo y letal para un clonador: el esqueje transpira sin poder
    # reponer. Con el rango de vegetativo (50-70) esto no disparaba absolutamente nada.
    it 'avisa por aire seco en un lote enraizando' do
      lote = create(:lote, club: club, sala: sala, estado: 'enraizado')
      registrar(lote, humedad: 60, temperatura: 24)

      expect(alertas(tipo: 'humedad_fuera_rango').count).to eq(1)
    end

    it 'con la humedad que corresponde al enraizado no avisa' do
      lote = create(:lote, club: club, sala: sala, estado: 'enraizado')
      registrar(lote, humedad: 90, temperatura: 24)

      expect(alertas(tipo: 'humedad_fuera_rango')).to be_empty
    end

    it 'el mismo 60% en vegetativo NO es un problema y no avisa' do
      lote = create(:lote, club: club, sala: sala, estado: 'vegetativo')
      registrar(lote, humedad: 60, temperatura: 24)

      expect(alertas(tipo: 'humedad_fuera_rango')).to be_empty
    end
  end

  describe 'EC: la falsa alarma que había' do
    # Un esqueje sin raíz no absorbe: EC casi nula es lo CORRECTO. Con el rango de vegetativo
    # (0.8-1.4) esto disparaba alerta de EC baja todos los días.
    it 'EC casi nula en enraizado no dispara alerta' do
      lote = create(:lote, club: club, sala: sala, estado: 'enraizado')
      registrar(lote, ec: 0.2, humedad: 90, temperatura: 24)

      expect(alertas(tipo: 'ec_fuera_rango')).to be_empty
    end

    it 'pero una EC de vegetativo en un clonador sí avisa: eso quema el callo' do
      lote = create(:lote, club: club, sala: sala, estado: 'enraizado')
      registrar(lote, ec: 1.4, humedad: 90, temperatura: 24)

      expect(alertas(tipo: 'ec_fuera_rango').count).to eq(1)
    end
  end

  # La temperatura de sustrato es la variable que decide si prende, más que la del aire. El campo
  # existía en RegistroAmbiental y nadie lo miraba.
  describe 'temperatura de sustrato' do
    it 'avisa con el sustrato frío aunque el aire esté perfecto' do
      lote = create(:lote, club: club, sala: sala, estado: 'enraizado')
      registrar(lote, temperatura: 24, humedad: 90, temperatura_sustrato: 18)

      expect(alertas(tipo: 'temperatura_sustrato_fuera_rango').count).to eq(1)
    end

    it 'con el sustrato en rango no avisa' do
      lote = create(:lote, club: club, sala: sala, estado: 'enraizado')
      registrar(lote, temperatura: 24, humedad: 90, temperatura_sustrato: 25)

      expect(alertas(tipo: 'temperatura_sustrato_fuera_rango')).to be_empty
    end

    # Vegetativo y floración no declaran rango de sustrato: el campo se saltea en vez de inventar
    # una alerta. Sin esto, sumar el campo al monitoreo llenaba el tablero de falsos positivos.
    it 'no inventa alertas de sustrato en fases que no lo declaran' do
      lote = create(:lote, club: club, sala: sala, estado: 'vegetativo')
      registrar(lote, temperatura: 24, humedad: 60, temperatura_sustrato: 15)

      expect(alertas(tipo: 'temperatura_sustrato_fuera_rango')).to be_empty
    end
  end

  describe 'días sin registro' do
    it 'el enraizado se mira todos los días, no cada tres' do
      lote = create(:lote, club: club, sala: sala, estado: 'enraizado')
      create(:registro_ambiental, lote: lote, club: club, user: admin,
                                  registrado_en: 2.days.ago, humedad: 90, temperatura: 24)

      expect(alertas(tipo: 'sin_registro_ambiental').count).to eq(1)
    end

    it 'los mismos 2 días en vegetativo todavía no son alerta' do
      lote = create(:lote, club: club, sala: sala, estado: 'vegetativo')
      create(:registro_ambiental, lote: lote, club: club, user: admin,
                                  registrado_en: 2.days.ago, humedad: 60, temperatura: 24)

      expect(alertas(tipo: 'sin_registro_ambiental')).to be_empty
    end
  end

  describe 'setpoints del club' do
    it 'un setpoint propio de enraizado le gana al rango por defecto' do
      SetpointFase.create!(club_id: club.id, fase: 'enraizado', tipo_lectura: 'humedad',
                           valor_min: 70, valor_max: 99, unidad: '%')
      lote = create(:lote, club: club, sala: sala, estado: 'enraizado')
      registrar(lote, humedad: 75, temperatura: 24)

      # 75 está fuera del default (85-95) pero dentro de lo que configuró el club.
      expect(alertas(tipo: 'humedad_fuera_rango')).to be_empty
    end

    it "la fase de setpoints se llama 'enraizado' (antes 'clon', que dejaba afuera las plántulas)" do
      expect(SetpointFase::FASES).to include('enraizado')
      expect(SetpointFase::FASES).not_to include('clon')
    end
  end
end

# El tiempo hasta que la raíz se enrolla NO es un número fijo de días: depende del volumen de la
# maceta. Por eso guardar el tamaño real —y no una etiqueta tipo "en vaso"— es lo que hace posible
# esta alerta.
RSpec.describe "#{AlertaDetectorService} — raíz enrollada" do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }

  around { |ex| ActsAsTenant.with_tenant(club) { ex.run } }

  def alerta_de(litros:, dias:, estado: 'vegetativo')
    create(:lote, club: club, sala: sala, estado: estado,
                  tamanio_maceta: litros, fecha_trasplante: dias.days.ago.to_date)
    AlertaDetectorService.new(club).detectar!
    club.alertas_internas.where(tipo: 'maceta_chica')
  end

  it 'en un vaso de 0,33L avisa a los ~12 días' do
    expect(alerta_de(litros: 0.33, dias: 20).count).to eq(1)
  end

  it 'los mismos 20 días en una maceta de 3L todavía no son problema' do
    expect(alerta_de(litros: 3, dias: 20)).to be_empty
  end

  it 'pero 40 días en 3L sí' do
    expect(alerta_de(litros: 3, dias: 40).count).to eq(1)
  end

  # Arriba de 4L se asume maceta final: no hay trasplante pendiente que avisar.
  it 'no avisa nunca en la maceta final' do
    expect(alerta_de(litros: 11, dias: 200)).to be_empty
  end

  # En enraizado la planta está en taco o plug: el reloj que corre es el del prendimiento, no este.
  it 'no aplica en enraizado' do
    expect(alerta_de(litros: 0.33, dias: 30, estado: 'enraizado')).to be_empty
  end

  it 'sin maceta cargada no inventa una alerta' do
    create(:lote, club: club, sala: sala, estado: 'vegetativo', tamanio_maceta: nil)
    AlertaDetectorService.new(club).detectar!
    expect(club.alertas_internas.where(tipo: 'maceta_chica')).to be_empty
  end

  it 'cuenta desde el ÚLTIMO trasplante, no desde el inicio del lote' do
    create(:lote, club: club, sala: sala, estado: 'vegetativo', tamanio_maceta: 0.5,
                  start_date: 90.days.ago.to_date, fecha_trasplante: 3.days.ago.to_date)
    AlertaDetectorService.new(club).detectar!
    expect(club.alertas_internas.where(tipo: 'maceta_chica')).to be_empty
  end
end
