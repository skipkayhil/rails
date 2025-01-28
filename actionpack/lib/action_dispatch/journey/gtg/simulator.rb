# frozen_string_literal: true

# :markup: markdown

require "strscan"

module ActionDispatch
  module Journey # :nodoc:
    module GTG # :nodoc:
      class MatchData # :nodoc:
        attr_reader :memos

        def initialize(memos)
          @memos = memos
        end
      end

      class Simulator # :nodoc:
        INITIAL_STATE = [0].freeze

        attr_reader :tt

        def initialize(transition_table)
          @tt = transition_table
        end

        def memos(string)
          input = StringScanner.new(string)
          state = INITIAL_STATE
          continuous_state = []
          start_index = 0

          while sym_length = input.skip(%r([/.?]|[^/.?]+))
            end_index = start_index + sym_length

            state, continuous_state = tt.move(state, continuous_state, string, start_index, end_index)

            start_index = end_index
          end

          acceptance_states = state.each_with_object([]) do |s, memos|
            memos.concat(tt.memo(s)) if tt.accepting?(s)
          end

          acceptance_states.empty? ? yield : acceptance_states
        end
      end
    end
  end
end
