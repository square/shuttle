# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :daily_metric do
    date                                { Time.utc(2014, 8, 12) }
    num_commits_loaded                  5
    num_commits_loaded_per_project      { {'Project One' => 3, 'Project Two' => 2} }
    avg_load_time                       3.0
    avg_load_time_per_project           { {'Project One' => 2.0, 'Project Two' => 4.0} }
    num_commits_completed               3
    num_commits_completed_per_project   { {'Project One' => 2, 'Project Two' => 1} }
    num_words_created                   50
    num_words_created_per_language      { {'jp' => 30, 'fr' => 20} }
    num_words_completed                 30
    num_words_completed_per_language    { {'jp' => 20, 'fr' => 10} }
  end
end
