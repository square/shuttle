FactoryBot.define do
  factory :article_group do
    association :article
    association :group
  end
end
