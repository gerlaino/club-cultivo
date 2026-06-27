require 'rails_helper'

RSpec.describe NotificacionesMailer, '#resumen_ruta', type: :mailer do
  let(:club) do
    create(:club, name: 'Mi Club',
           smtp_host: 'smtp.gmail.com', smtp_port: 587, smtp_user: 'm@gmail.com',
           smtp_pass: 'p', smtp_from: 'm@gmail.com', smtp_from_name: 'Mi Club')
  end
  let!(:admin)   { create(:user, :admin, club: club, email: 'admin@miclub.com') }
  let(:delivery) { create(:user, club: club, role: 'delivery', first_name: 'Dani', last_name: 'R') }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)     { create(:lote, club: club, sala: sala) }
  let(:pac)      { create(:paciente, club: club, created_by: admin, email: 'p@gmail.com') }
  let(:stock)    { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100, precio_sugerido_ars: 5000) }

  let(:disp) do
    Dispensacion.create!(paciente: pac, user: admin, stock: stock, sede: sede, cantidad: 1,
                         medio_pago: 'efectivo', fecha_dispensacion: Date.today, aporte_socio_ars: 5000,
                         con_envio: true, delivery_id: delivery.id, estado_envio: 'entregado',
                         direccion_envio: 'Calle 1', contacto_nombre: 'P')
  end

  it 'incluye la caja del delivery y cómo pagó cada socio' do
    Cobro.create!(dispensacion: disp, club: club, created_by: delivery,
                  medio: 'efectivo', monto_ars: 5000, contexto: 'entrega', rendido: false)

    mail = described_class.resumen_ruta(club: club, delivery: delivery,
                                        entregados: [disp.reload], fallidos: [], caja_efectivo: 5000)
    cuerpo = mail.body.encoded
    expect(cuerpo).to include('Caja del delivery')
    expect(cuerpo).to match(/5\.000/)              # monto formateado
    expect(cuerpo).to match(/Efectivo/)            # cómo pagó
  end

  it 'va a TODOS los admins, usando el email personal (real) cuando existe' do
    admin.update!(email: 'admin1@login.local', email_personal: 'admin1@gmail.com') # login inventado, personal real
    create(:user, :admin, club: club, email: 'admin2@gmail.com')                   # sin personal → cae al login

    mail = described_class.resumen_ruta(club: club, delivery: delivery,
                                        entregados: [disp.reload], fallidos: [], caja_efectivo: 0)
    expect(mail.to).to contain_exactly('admin1@gmail.com', 'admin2@gmail.com')
  end
end
