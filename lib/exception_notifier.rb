module ExceptionNotifier
  extend self

  def notify(e, parameters = {})
    with_error_recovery do
      Raven.capture_exception(e, extra: parameters)
    end
  end

  def notify_string(message, parameters = {})
    fail message
  rescue RuntimeError => e
    notify(e, parameters)
  end

  def notify_message(message, parameters = {})
    # Log the original exception in case we hit an error during exception delivery
    Rails.logger.warn(Sq::Redactor.redact(message))

    Raven.capture_message(
      Sq::Redactor.redact(message),
      extra: parameters,
      tags: { environment: Rails.env },
    )
  end

  def with_error_recovery
    yield
  rescue StandardError => e
    Rails.logger.error("Failed to log exception due to #{e.inspect}")
  end
end
