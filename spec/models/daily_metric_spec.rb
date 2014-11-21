require 'spec_helper'

describe DailyMetric do
  context "[validations]" do
    it "validates presence of date" do
      metric = FactoryGirl.build :daily_metric, date: nil
      expect(metric).to_not be_valid
    end

    metric_fields = [:num_commits_loaded,
                     :avg_load_time,
                     :num_commits_completed,
                     :num_words_created,
                     :num_words_completed]
    metric_fields.each do |field|
      it "validates presence of #{field}" do
        metric = FactoryGirl.build :daily_metric, field => nil
        expect(metric).to_not be_valid
      end
    end

    it "should be valid if all required fields are present" do
      metric = FactoryGirl.build :daily_metric
      expect(metric).to be_valid
    end
  end
end
