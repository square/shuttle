class StatsController < ApplicationController
  before_filter :authenticate_user!

  respond_to :json
  respond_to :html, only: :index 

  def index
    @top_projects = Translation.total_words_per_project.map { |t| { name: t[0], id: Project.find_by_name(t[0]).id } }[0..4]
    # Commit stats
    @total_commits = Commit.total_commits
    @total_commits_incomplete = Commit.total_commits_incomplete
    @total_words = Translation.total_words
    @total_words_new = Translation.total_words_new
    @total_words_pending = Translation.total_words_pending
  end 

  def words_per_project
    respond_with Translation.total_words_per_project
  end

  def average_completion_time
    respond_with Commit.average_completion_time
  end

  def daily_commits_created
    respond_with Commit.daily_commits_created
  end 

  def daily_commits_finished
    respond_with Commit.daily_commits_finished
  end 

  def avg_completion_and_daily_creates
    respond_with(
      average_completion_time: Commit.average_completion_time(params['project_id']),
      daily_creates: Commit.daily_commits_created(params['project_id'])
    )
  end 
end
