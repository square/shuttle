FactoryGirl.define do
  factory :blobs_commit do
    association :blob
    association :commit
  end
end
