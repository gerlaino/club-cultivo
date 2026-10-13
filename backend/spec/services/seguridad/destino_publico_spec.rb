require 'rails_helper'

# El servidor sólo se conecta a direcciones públicas cuando el destino lo escribe un usuario
# (webhooks salientes, SMTP propio). Barrido de seguridad, 13-oct-2026.
RSpec.describe Seguridad::DestinoPublico do
  it 'rechaza loopback, redes privadas, link-local (metadata de la nube) e IPv6 internas' do
    %w[127.0.0.1 10.0.0.5 172.16.3.4 192.168.1.1 169.254.169.254 100.64.0.1 0.0.0.0
       ::1 fd00::1 fe80::1 ::ffff:127.0.0.1].each do |ip|
      expect { described_class.ip!(ip) }.to raise_error(described_class::Rechazado), "dejó pasar #{ip}"
    end
  end

  it 'acepta una IP pública y la devuelve' do
    expect(described_class.ip!('8.8.8.8')).to eq('8.8.8.8')
    expect(described_class.ip!('[2001:4860:4860::8888]')).to eq('2001:4860:4860::8888')
  end

  it 'rechaza un dominio si CUALQUIERA de sus direcciones es privada' do
    allow(described_class).to receive(:direcciones).with('mixto.example').and_return(%w[8.8.8.8 10.0.0.1])
    expect { described_class.ip!('mixto.example') }.to raise_error(described_class::Rechazado)
  end

  it 'devuelve la IP pública de un dominio para conectarse a ESA' do
    allow(described_class).to receive(:direcciones).with('hooks.example').and_return(%w[93.184.215.14])
    expect(described_class.ip!('hooks.example')).to eq('93.184.215.14')
  end

  it 'rechaza un dominio que no resuelve y un host vacío' do
    allow(described_class).to receive(:direcciones).with('nada.example').and_return([])
    expect { described_class.ip!('nada.example') }.to raise_error(described_class::Rechazado)
    expect { described_class.ip!('') }.to raise_error(described_class::Rechazado)
  end
end
