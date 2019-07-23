require 'csv'

class ReportsController < ApplicationController
    def index
        @today = Date.today
        @yesterday = Date.yesterday
        @range = Date.today...Date.today - 30
    end

    def incoming
        parsed_date = Date.parse(params[:date])
        range = parsed_date.beginning_of_day...parsed_date.end_of_day
        @report = Report.where(date: range).where(report_type: 'incoming')
        send_data convert_json_to_csv(@report), type: 'text/plain',
            filename: "incoming-#{params[:date]}.csv",
            disposition: :attachment
    end

    def pending
        range = Date.parse(params[:date])...Date.tomorrow
        @report = Report.where(date: range).where(report_type: 'pending')
        send_data convert_json_to_csv(@report), type: 'text/plain',
            filename: "pending-#{params[:date]}.csv",
            disposition: :attachment
    end

    def completed
        range = Date.parse(params[:date])...Date.tomorrow
        @report = Report.where(date: range).where(report_type: 'completed')
        send_data convert_json_to_csv(@report), type: 'text/plain',
            filename: "completed-#{params[:date]}.csv",
            disposition: :attachment
    end

    def convert_json_to_csv(jobs)
        csv_file = CSV.generate do |csv|
            csv << ['project_name', 'targeted_locale', 'strings', 'words', 'date']
            jobs.each do |job|
                csv << [job[:project], job[:locale], job[:strings], job[:words], job[:date]]
            end
        end
        csv_file
    end
end
