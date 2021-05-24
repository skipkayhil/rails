# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      class SchemaCache < ActiveRecord::ConnectionAdapters::SchemaCache
        def initialize(*)
          super

          @additional_type_records = []
          @known_coder_type_records = []
        end

        def initialize_dup(other)
          super

          @additional_type_records  = @additional_type_records.dup
          @known_coder_type_records = @known_coder_type_records.dup
        end

        def encode_with(coder)
          super

          coder["additional_type_records"]  = @additional_type_records
          coder["known_coder_type_records"] = @known_coder_type_records
        end

        def init_with(coder)
          @additional_type_records  = coder["additional_type_records"]
          @known_coder_type_records = coder["known_coder_type_records"]

          super
        end

        def additional_type_records
          if @additional_type_records.present?
            @additional_type_records.each { |records| yield records } if block_given?
            @additional_type_records
          else
            connection.additional_type_records do |records|
              @additional_type_records << records
              yield records
            end
          end
        end

        def known_coder_type_records
          return @known_coder_type_records if @known_coder_type_records.present?

          @known_coder_type_records = connection.known_coder_type_records
        end

        def clear!
          clear_types!
          @known_coder_type_records.clear

          super
        end

        def clear_types!
          @additional_type_records.clear
        end

        def marshal_dump
          super.push(@additional_type_records, @known_coder_type_records)
        end

        def marshal_load(array)
          @additional_type_records, @known_coder_type_records = array.pop(2)

          super
        end

        private
          def prepare_dump
            super

            connection.initialize_type_map
            known_coder_type_records
          end
      end
    end
  end
end
