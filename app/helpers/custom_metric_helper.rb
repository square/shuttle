module CustomMetricHelper
  extend self

  SIDEKIQ_WORKER_LONGEVITY = 'SidekiqWorker/longevity'
  SIDEKIQ_WORKER_JOBS_BUSY = 'SidekiqWorker/jobs/busy'
  SIDEKIQ_WORKER_JOBS_ENQUEUED = 'SidekiqWorker/jobs/enqueued'

  PROJECT_PROCESSING_LOADING_TIME = 'project/processing/loading'
  PROJECT_PROCESSING_TRANSLATING_TIME = 'project/processing/translating'
  PROJECT_PROCESSING_REVIEWING_TIME = 'project/processing/translating'
  PROJECT_PROCESSING_READY_TIME = 'project/processing/ready'
  PROJECT_PROESSSING_STASH_TIME = 'project/processing/stash'

  PROJECT_STATISTICS_FILES = 'project/statistics/files'
  PROJECT_STATISTICS_STRINGS = 'project/statistics/strings'
  PROJECT_STATISTICS_WORDS = 'project/statistics/words'

  def record_sidekiq_longevity(host_to_longevities)
    host_to_longevities.each do |hostname, longevity|
      record_metric(longevity, SIDEKIQ_WORKER_LONGEVITY, hostname)
    end
  end

  def record_sidekiq_jobs(busy_jobs, enqueued_jobs)
    record_metric(busy_jobs, SIDEKIQ_WORKER_JOBS_BUSY)
    record_metric(enqueued_jobs, SIDEKIQ_WORKER_JOBS_ENQUEUED)
  end

  # time from project created to loaded
  def record_project_loading_time(project_name, loading_time)
    record_metric(loading_time, PROJECT_PROCESSING_LOADING_TIME, project_name)
  end

  # time from project loaded to fully translated
  def record_project_translating_time(project_name, locale_name, translating_time)
    record_metric(translating_time, PROJECT_PROCESSING_TRANSLATING_TIME, project_name, locale_name)
  end

  # time from project fully translated to fully reviewed
  def record_project_reviewing_time(project_name, locale_name, reviewing_time)
    record_metric(reviewing_time, PROJECT_PROCESSING_REVIEWING_TIME, project_name, locale_name)
  end

  # time from project created to ready
  def record_project_ready_time(project_name, ready_time)
    record_metric(ready_time, PROJECT_PROCESSING_READY_TIME, project_name)
  end

  # time from project approved to ping done
  def record_project_ping_stash_time(project_name, ping_stash_time)
    record_metric(ping_stash_time, PROJECT_PROESSSING_STASH_TIME, project_name)
  end

  # counts for project files, keys per locale and words per locale
  def record_project_statistics(project_name, blobs, locales_to_keys, locales_to_words)
    record_metric(blobs, PROJECT_STATISTICS_FILES, project_name)

    locales_to_keys.each do |locale_name, keys|
      record_metric(keys, PROJECT_STATISTICS_STRINGS, project_name, locale_name)
    end

    locales_to_words.each do |locale_name, words|
      record_metric(words, PROJECT_STATISTICS_WORDS, project_name, locale_name)
    end
  end

  private

  def record_metric(metric, metric_name, *sub_metric_names)
    full_metric_name = (['Custom', metric_name] + sub_metric_names).join('/')
    ::NewRelic::Agent.record_metric(full_metric_name, metric)
  end
end
