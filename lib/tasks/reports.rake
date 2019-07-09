# frozen_string_literal: true

require 'csv'

# This namespace is used to generate reports for incoming, pending, and
# completed jobs over a given time

namespace :reports do
  desc 'Get reports for projects in Shuttle'
  namespace :generate do
    task incoming: :environment do
      system('clear') || system('cls')
      puts "[reports:generate:incoming] Creating a new report for #{Date.today}"
      generate_incoming_report
    end
    
    task pending: :environment do
      system('clear') || system('cls')
      puts "[reports:generate:pending] Creating a new report for #{Date.today}"
      generate_pending_report
    end

    task completed: :environment do
      system('clear') || system('cls')
      puts "[reports:generate:completed] Creating a new report for #{Date.today}"
      generate_completed_report
    end
  end

  def generate_incoming_report
    filename = "incoming-#{get_display_date}.csv"
    date_start = Date.yesterday.beginning_of_day
    date_range = date_start...Date.yesterday.end_of_day

    commits_loaded = get_commits(date_range)
    articles_loaded = get_articles(date_range)
    untranslated_commit_keys = get_untranslated_keys(commits_loaded)
    untranslated_article_keys = get_untranslated_keys(articles_loaded)

    puts "Found #{untranslated_commit_keys.count} commits and #{untranslated_article_keys.count} articles from #{date_start} to #{Date.today}"

    combined_jobs = commits_loaded.concat(articles_loaded)
    jobs = create_hash_for_export(combined_jobs)
    save_incoming_translations jobs
  end

  def generate_pending_report
    filename = "pending-#{get_display_date}.csv"
    yesterday = Date.yesterday
    date_range = yesterday...Date.today

    commits_loaded = get_commits(date_range)
    articles_loaded = get_articles(date_range)
    untranslated_commit_keys = get_untranslated_keys(commits_loaded)
    untranslated_article_keys = get_untranslated_keys(articles_loaded)

    puts "Found #{untranslated_commit_keys.count} commits and #{untranslated_article_keys.count} articles from #{yesterday} to #{Date.today}"
    combined_jobs = commits_loaded.concat(articles_loaded)
    jobs = create_hash_for_export(combined_jobs)
    save_pending_translations jobs
  end

  def generate_completed_report
    filename = "completed-#{get_display_date}.csv"
    yesterday = Date.yesterday
    date_range = yesterday...Date.today

    completed_translations = get_completed_translations(date_range)
    parsed_translations = get_report_from completed_translations
    save_completed_translations parsed_translations
  end

  private

  def get_commits(range)
    Commit.where(loaded_at: range)
  end

  def get_articles(range)
    Article.where(created_at: range)
  end

  def get_untranslated_keys(list_of_jobs)
    list_of_untranslated_keys = []
    list_of_jobs.where(ready: false).each do |job|
      list_of_untranslated_keys << job.keys.where(ready: false)
    end
  end

  def get_completed_translations(range)
    commits = Commit.where(approved_at: range)
    articles = Article.where(last_completed_at: range)
    jobs = commits.concat(articles)
    completed_translations = []
    puts "jobs in tranlsated: #{jobs.count}"
    jobs.each do |job|
      translations = job.translations.where updated_at: range
      completed_translations << translations.flatten
    end
    completed_translations.flatten
  end

  def get_report_from(translations)
    export_hash = {}
    translations.each do |translation|
      project_name = translation.key.project.name
      locale = translation.rfc5646_locale
      identifier = :"#{project_name}_#{locale}"
      unless export_hash[identifier]
        export_hash[identifier] = {
          project: project_name,
          locale: locale,
          strings: 0,
          words: 0
        }
      end
      export_hash[identifier][:strings] = export_hash[identifier][:strings] + 1
      export_hash[identifier][:words] = export_hash[identifier][:words] + translation.words_count
    end
    export_hash
  end

  def create_hash_for_export(list_of_jobs)
    jobs = {}
    list_of_jobs.each do |job|
      job.keys.where(ready: false).each do |key|
        project = Project.find(key.project_id)
        project_name = project.name
        job.targeted_rfc5646_locales.each do |locale, _exists|
          identifier = :"#{project_name}_#{locale}"
          unless jobs[identifier]
            jobs[identifier] = {
              locale: locale,
              project: project,
              strings: 0,
              words: 0
            }
          end
          jobs[identifier][:strings] = jobs[identifier][:strings] + 1
          key.translations.where(approved: [false, nil]).each do |translation|
            jobs[identifier][:words] = jobs[identifier][:words] + translation.words_count
          end
        end
      end
    end
    jobs
  end

  def save_completed_translations(translations)
    translations.each do |_identifier, stats|
      r = Report.new
      r.project = stats[:project]
      r.locale = stats[:locale]
      r.strings = stats[:strings]
      r.words = stats[:words]
      r.date = Date.today
      r.report_type = :completed
      r.save
    end
  end

  def save_incoming_translations(translations)
    translations.each do |_identifier, stats|
      r = Report.new
      r.project = stats[:project].name
      r.locale = stats[:locale]
      r.strings = stats[:strings]
      r.words = stats[:words]
      r.date = Date.today
      r.report_type = :incoming
      r.save
    end
  end

  def save_pending_translations(translations)
    translations.each do |_identifier, stats|
      r = Report.new
      r.project = stats[:project].name
      r.locale = stats[:locale]
      r.strings = stats[:strings]
      r.words = stats[:words]
      r.date = Date.today
      r.report_type = :pending
      r.save
    end
  end

  def get_display_date
    Date.today.strftime("%Y-%m-%d")
  end
end
