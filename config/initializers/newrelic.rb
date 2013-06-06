# This file contains monkey patches for adding additional NewRelic RPM tracing.
# https://newrelic.com/docs/ruby/ruby-custom-metric-collection#example_initializer
require 'new_relic/agent/method_tracer'

Exporter::Base.class_eval do
  include ::NewRelic::Agent::MethodTracer

  add_method_tracer :translation_hash
end

Importer::Base.class_eval do
  include ::NewRelic::Agent::MethodTracer

  add_method_tracer :extract_hash
  add_method_tracer :extract_array
  add_method_tracer :process_blob_for_string_extraction
  add_method_tracer :process_blob_for_translation_extraction
end

Importer::Base.implementations.each do |klass|
  klass.class_eval do
    include ::NewRelic::Agent::MethodTracer
    add_method_tracer :import
    add_method_tracer :import_locale
  end
end
