# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :comment do
    content "MyText"
    user
    issue
  end
end
