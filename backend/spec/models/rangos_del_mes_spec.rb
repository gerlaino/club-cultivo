require 'rails_helper'

# `Date#all_month` devuelve un rango de DATES. Comparado contra una columna de timestamp, el
# borde de arriba es la MEDIANOCHE del último día: todo lo que pasó ese día queda afuera.
#
# Durante el mes no se nota, porque el borde está en el futuro. El día 31 sí: el consumo de IA de
# esa jornada no se contaba —el tope no se aplicaba y el cliente tenía un día gratis por mes— y
# el informe de pérdidas perdía el día entero, que es justo cuando alguien cierra el mes.
#
# (`Date#all_day` NO tiene el problema: sobre una Date devuelve Times.)
RSpec.describe 'Los rangos mensuales llegan hasta el final del último día' do
  let(:club) { create(:club) }

  # El último día del mes, a media tarde: el momento exacto en que el bug se ve.
  def en_el_ultimo_dia(&)
    travel_to(Time.zone.today.end_of_month.to_time.change(hour: 15), &)
  end

  it 'cuenta el consumo de IA del último día del mes' do
    en_el_ultimo_dia do
      ActsAsTenant.with_tenant(club) do
        Ia::Uso.registrar(club: club, funcion: :asistente_parsear, modelo: 'claude-sonnet-4-6',
                          tokens: { input: 1_000 })

        expect(IaLlamada.where(club_id: club.id).del_mes.count).to eq(1)
        expect(Ia::Uso.resumen_mes(club)[:llamadas]).to eq(1)
      end
    end
  end

  it 'y las correcciones del asistente del último día' do
    en_el_ultimo_dia do
      ActsAsTenant.with_tenant(club) do
        create(:user, :admin, club: club).then do |u|
          AsistenteCorreccion.create!(club: club, user: u, texto: 'poné 3 plantas en A',
                                      hubo_correccion: false)
        end

        expect(AsistenteCorreccion.where(club_id: club.id).del_mes.count).to eq(1)
      end
    end
  end
end
