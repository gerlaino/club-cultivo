require 'rails_helper'

# Los vectores del RFC 6238 (apéndice B, SHA1, secreto ASCII «12345678901234567890»): si esto pasa,
# los códigos coinciden con los de Google Authenticator / 1Password.
RSpec.describe Seguridad::Totp do
  let(:secreto) { 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ' }

  { 59 => '287082', 1_111_111_109 => '081804', 1_234_567_890 => '005924', 2_000_000_000 => '279037' }.each do |t, esperado|
    it "a los #{t} segundos da #{esperado}" do
      expect(described_class.codigo(secreto, t / 30)).to eq(esperado)
    end
  end

  it 'acepta el código de ahora y el del paso anterior o siguiente (reloj corrido), no más' do
    ahora = Time.zone.at(1_234_567_890)
    paso  = described_class.paso_de(ahora)
    expect(described_class.verificar(secreto, described_class.codigo(secreto, paso), tiempo: ahora)).to eq(paso)
    expect(described_class.verificar(secreto, described_class.codigo(secreto, paso - 1), tiempo: ahora)).to eq(paso - 1)
    expect(described_class.verificar(secreto, described_class.codigo(secreto, paso + 1), tiempo: ahora)).to eq(paso + 1)
    expect(described_class.verificar(secreto, described_class.codigo(secreto, paso - 2), tiempo: ahora)).to be_nil
  end

  it 'un código ya usado no vale de nuevo' do
    ahora = Time.zone.at(1_234_567_890)
    paso  = described_class.paso_de(ahora)
    expect(described_class.verificar(secreto, described_class.codigo(secreto, paso), ultimo_paso: paso, tiempo: ahora)).to be_nil
  end

  it 'basura no vale' do
    expect(described_class.verificar(secreto, '12a456')).to be_nil
    expect(described_class.verificar(secreto, '')).to be_nil
    expect(described_class.verificar(nil, '123456')).to be_nil
  end

  it 'el secreto nuevo es base32 de 32 caracteres y se decodifica a 20 bytes' do
    s = described_class.generar_secreto
    expect(s).to match(/\A[A-Z2-7]{32}\z/)
    expect(described_class.decodificar(s).bytesize).to eq(20)
  end

  it 'el QR lleva el emisor y la cuenta' do
    expect(described_class.uri('ABC', 'german@x.com')).to start_with('otpauth://totp/Cultivo%20Espacial%3Agerman%40x.com?secret=ABC&issuer=Cultivo%20Espacial')
  end
end
