# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      class SchemaCacheTest < ActiveRecord::TestCase
        def setup
          @connection       = ActiveRecord::Base.connection
          @cache            = @connection.init_schema_cache
        end

        def test_yaml_dump_and_load
          # Create an empty cache.
          cache = @connection.init_schema_cache

          tempfile = Tempfile.new(["schema_cache-", ".yml"])
          # Dump it. It should get populated before dumping.
          cache.dump_to(tempfile.path)

          # Load the cache.
          cache = SchemaCache.load_from(tempfile.path)

          # Give it a connection. Usually the connection
          # would get set on the cache when it's retrieved
          # from the pool.
          cache.connection = @connection

          assert_no_queries do
            cache.additional_type_records { |records| assert_not_nil records }
          end
        ensure
          tempfile.unlink
        end

        def test_additional_types_cached
          assert_queries(3, { ignore_none: true }) do
            @cache.additional_type_records { }
          end
          assert_no_queries do
            assert_equal 3, @cache.additional_type_records.length
          end
        end

        def test_known_coder_types_cached
          assert_queries(1, { ignore_none: true }) { @cache.known_coder_type_records }
          assert_no_queries { @cache.known_coder_type_records }
        end
      end
    end
  end
end
