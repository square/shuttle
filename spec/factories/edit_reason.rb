# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :edit_reason do
    association :translation_change
  end
end
