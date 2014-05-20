class DailyMetric < ActiveRecord::Base
  include HasMetadataColumn
  has_metadata_column(
    num_commits_loaded:                {type: Integer},
    num_commits_loaded_per_project:    {type: Hash},
    avg_load_time:                     {type: Float},
    avg_load_time_per_project:         {type: Hash},
    num_commits_completed:             {type: Integer},
    num_commits_completed_per_project: {type: Hash},
    num_words_created:                 {type: Integer},
    num_words_created_per_language:    {type: Hash},
    num_words_completed:               {type: Integer},
    num_words_completed_per_language:  {type: Hash},
  )

  validates :date,
            presence: true
end
