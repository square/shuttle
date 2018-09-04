FactoryBot.define do
  factory :asset do
    association :project, repository_url: nil
    association :user
    sequence(:name) { |i| "asset-#{i}" }
    sequence(:file_name) { |i| "asset-file#{i}.xlsx" }
    file { File.new("#{Rails.root}/spec/fixtures/excel-simple.xlsx") }
  end
end
