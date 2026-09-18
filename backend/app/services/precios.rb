# Cuánto cuesta cada cosa, por mes y en pesos. UNA constante, no una tabla: los precios cambian
# dos veces por año y con un commit alcanza; una pantalla para editarlos es una perilla más que
# nadie pidió. Cuando haya que cobrar distinto a una organización, ese día se agrega una columna
# de descuento — no antes.
#
# Hasta sep-2026 nada decía cuánto costaba nada: el plan decía CUÁNTO, los módulos decían QUÉ,
# y `mrr: 0` estaba escrito a mano en un endpoint que ninguna pantalla llamaba. «Se está
# perdiendo plata» era una frase sin número.
#
# LOS NÚMEROS DE ABAJO SON PROVISORIOS (16-sep-2026): quedan hasta que Germán fije la lista.
#
# Cómo se suma (`Precios.de(club)`): el plan (la base, por sus topes) + cada suite contratada +
# cada adicional prendido. Lo dado de baja con fecha sigue costando hasta que venza: se paga el
# mes entero. Los bloqueados (`Club::ADDONS_BLOQUEADOS`) cuestan 0 porque no se pueden vender.
module Precios
  MONEDA = 'ARS'.freeze

  PLANES = {
    'basico'   => 40_000,
    'total'    => 90_000,
    # Uso personal: UN número. Cultivo y el ambiente van adentro (ver `INCLUIDO_EN_PERSONAL`);
    # lo único que se suma aparte es la IA. Provisorio como los demás.
    'personal' => 12_000,
  }.freeze

  # Lo que el plan personal trae adentro y no se cobra como línea aparte.
  INCLUIDO_EN_PERSONAL = %w[cultivo iot].freeze

  SUITES = {
    'cultivo'             => 30_000,
    'produccion_dispensa' => 45_000,
  }.freeze

  ADDONS = {
    'bar'            => 10_000,
    'eventos'        =>  8_000,
    'delivery'       => 15_000,
    'mailer'         =>  6_000,
    'vista_paciente' => 12_000,
    'whatsapp'       =>      0,   # bloqueado: no se vende todavía
    'ariccame'       =>      0,   # bloqueado: la transmisión está simulada
    'iot'            => 20_000,
    'ia'             => 25_000,
    'chatbot'        => 10_000,
  }.freeze

  def self.plan(clave)  = PLANES.fetch(PlanEnforcer.normalizar(clave), 0)
  def self.suite(clave) = SUITES.fetch(clave.to_s, 0)
  def self.addon(clave) = ADDONS.fetch(clave.to_s, 0)

  # El desglose de una organización: qué paga y por qué, con el total. Es lo que se muestra en
  # la ficha y lo que suma el panel.
  def self.de(club)
    lineas = []
    lineas << { tipo: 'plan', clave: PlanEnforcer.normalizar(club.plan),
                label: "Plan #{PlanEnforcer::PLANES.dig(PlanEnforcer.normalizar(club.plan), :label)}",
                monto: plan(club.plan) }

    Club::SUITES.each_key do |k|
      next unless club.suite?(k)
      next if club.personal? && INCLUIDO_EN_PERSONAL.include?(k)
      lineas << { tipo: 'suite', clave: k, label: Club::SUITES.dig(k, :label), monto: suite(k) }
    end

    Club::ADDONS.each_key do |k|
      next unless club.feature?(k)
      next if club.personal? && INCLUIDO_EN_PERSONAL.include?(k)
      lineas << { tipo: 'addon', clave: k, label: Club::ADDONS.dig(k, :label), monto: addon(k) }
    end

    { lineas: lineas, total: lineas.sum { |l| l[:monto] }, moneda: MONEDA }
  end
end
