FactoryBot.define do
  factory :user do
    association :club
    sequence(:email) { |n| "user#{n}@example.com" }
    password         { 'password123' }
    role             { 'admin' }

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
