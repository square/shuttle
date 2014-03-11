FactoryGirl.define do
  factory :blobs_key do
    association :blobs
    association :keys
  end
end
