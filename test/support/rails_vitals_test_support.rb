module RailsVitalsTestSupport
  QueryEvent = Struct.new(:payload, :duration, keyword_init: true)

  def with_stub(target, method_name, return_value = nil)
    metaclass = target.singleton_class
    had_original = metaclass.method_defined?(method_name) || metaclass.private_method_defined?(method_name)
    original_method = metaclass.instance_method(method_name) if had_original

    metaclass.define_method(method_name) do |*args, **kwargs, &block|
      if return_value.respond_to?(:call)
        return_value.call(*args, **kwargs, &block)
      else
        return_value
      end
    end

    yield
  ensure
    if had_original
      metaclass.define_method(method_name, original_method)
    else
      metaclass.send(:remove_method, method_name) rescue nil
    end
  end

  def with_rails_vitals_config(overrides = {})
    config = RailsVitals.config
    original_values = config.instance_variables.to_h { |ivar| [ ivar, config.instance_variable_get(ivar) ] }

    overrides.each do |key, value|
      config.public_send("#{key}=", value)
    end

    yield
  ensure
    original_values.each do |ivar, value|
      config.instance_variable_set(ivar, value)
    end
  end

  def build_query(sql:, duration_ms:, source: "app/models/example.rb")
    {
      sql: sql,
      duration_ms: duration_ms,
      source: source,
      called_at: Time.current
    }
  end

  def build_collector(queries: [], callbacks: [])
    collector = RailsVitals::Collector.new
    queries.each { |query| collector.queries << query }
    callbacks.each { |callback| collector.callbacks << callback }
    collector
  end
end
