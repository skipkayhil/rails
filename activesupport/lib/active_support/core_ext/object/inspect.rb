# frozen_string_literal: true

if RUBY_VERSION < "4.0"
  class Object
    def inspect
      return super unless respond_to?(:instance_variables_to_inspect, true)

      buf = "#<#{self.class}:#{'%#016x' % (object_id << 1)}"

      instance_variables_to_inspect.each_with_index do |var, i|
        next unless instance_variable_defined? var

        buf << "," unless i == 0

        buf << " #{var}=#{instance_variable_get(var).inspect}"
      end

      buf << ">"
    end
  end
end
