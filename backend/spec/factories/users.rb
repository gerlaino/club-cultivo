FactoryBot.define do
  factory :user do
    association :club
    sequence(:email) { |n| "user#{n}@example.com" }
    password         { 'password123' }
    role             { 'admin' }

    # El super admin tiene el segundo paso obligatorio (29-oct-2026): por defecto nace con él
    # ACTIVO —como en producción una vez activado— y `sign_in_as` manda el código solo. Para probar
    # al que todavía no lo activó: `segundo_paso { false }`.
    transient do
      segundo_paso { true }
    end
    after(:build) do |u, ev|
      if u.role.to_s == 'super_admin' && ev.segundo_paso && u.otp_secret.blank?
        u.otp_secret      = Seguridad::Totp.generar_secreto
        u.otp_activado_at = Time.current
      end
    end

    trait :admin do
      role { 'admin' }
    end

    trait :cultivador do
      role { 'cultivador' }
    end

    trait :auditor do
      role { 'auditor' }
    end

    trait :dispensador do
      role { 'dispensador' }
    end

    trait :paciente do
      role { 'paciente' }
    end

    trait :socio do
      role { 'paciente' }
    end

    trait :abogado do
      role { 'abogado' }
    end

    trait :delivery do
      role { 'delivery' }
    end

    trait :manicura do
      role { 'manicura' }
    end

    trait :medico do
      role { 'medico' }
    end

    trait :super_admin do
      role { 'super_admin' }
      after(:build) { |u| u.club = nil; u.club_id = nil }
    end
  end
end
