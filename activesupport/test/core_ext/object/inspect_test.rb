# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/object"

class ObjectInspectTest < ActiveSupport::TestCase
  test "inspect uses super if instance_variables_to_inspect undefined" do
    o = Object.new
    o.instance_eval do
      @a = 1
      @b = "hello"
      @c = nil
    end

    inspected = o.inspect.sub(/^#<Object:0x[0-9a-f]+/, "#<Object:0x00")
    assert_equal '#<Object:0x00 @a=1, @b="hello", @c=nil>', inspected
  end

  test "inspect uses patch if instance_variables_to_inspect defined" do
    o = Object.new
    o.instance_eval do
      @a = 1
      @b = "hello"
      @c = nil
    end
    o.singleton_class.class_eval do
      private def instance_variables_to_inspect = [:@a, :@b, :@d]
    end

    inspected = o.inspect.sub(/^#<Object:0x[0-9a-f]+/, "#<Object:0x00")
    assert_equal '#<Object:0x00 @a=1, @b="hello">', inspected
  end
end
