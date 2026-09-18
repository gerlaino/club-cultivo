# Con qué arranca un uso personal, además del admin que lo contrató.
#
# Una organización empieza creando su sede, y tiene sentido: son varias, tienen dirección y de
# ahí cuelga todo. El cultivador de casa no tiene sedes: tiene su casa, y la primera pantalla
# que le pide «crear una sede» le habla de otra cosa. Se la creamos con el nombre que la
# describe y lo mandamos directo a lo suyo, que son las salas y el lote.
#
# Sólo la sede. Las salas NO se siembran: cuántas tiene y de qué tipo (una carpa mixta o vege +
# flora) es la primera decisión real de su cultivo, y es suya.
module Clubs
  class SembrarPersonal
    NOMBRE_SEDE = 'Mi cultivo'.freeze

    def initialize(club, por:)
      @club = club
      @por  = por
    end

    def call
      ActsAsTenant.with_tenant(@club) do
        return @club.sedes.first if @club.sedes.exists?

        sede = @club.sedes.create!(nombre: NOMBRE_SEDE, tipo: 'produccion', created_by: @por)
        Finanzas::SembrarDepositos.new(@club).call
        sede
      end
    end
  end
end
