# Instrument ElasticSearch code in NewRelic

ActiveSupport::Notifications.subscribe('import_objects.chewy') do |_name, start, finish|
  metric_name = 'Database/ElasticSearch/import'
  duration    = (finish - start).to_f

  self.class.trace_execution_scoped([metric_name]) do
    # NewRelic::Agent.instance.transaction_sampler.notice_sql(logged, nil, duration)
    # NewRelic::Agent.instance.sql_sampler.notice_sql(logged, metric_name, nil, duration)
    NewRelic::Agent.record_metric(metric_name, duration)
  end
end

ActiveSupport::Notifications.subscribe('search_query.chewy') do |_name, start, finish|
  metric_name = 'Database/ElasticSearch/search'
  duration    = (finish - start).to_f

  self.class.trace_execution_scoped([metric_name]) do
    # NewRelic::Agent.instance.transaction_sampler.notice_sql(logged, nil, duration)
    # NewRelic::Agent.instance.sql_sampler.notice_sql(logged, metric_name, nil, duration)
    NewRelic::Agent.record_metric(metric_name, duration)
  end
end
