# frozen_string_literal: true

require "abstract_unit"

module ActionDispatch
  module Journey
    module GTG
      class TestBuilder < ActiveSupport::TestCase
        def test_following_states_multi
          table = tt ["a|a"]

          state = [0]
          table.move(state, [], "a", 0, 1)
          assert_equal 1, state.length
        end

        def test_following_states_multi_regexp
          table = tt [":a|b"]

          state = [0]
          table.move(state, [], "fooo", 0, 4)
          assert_equal 1, state.length

          state = [0]
          table.move(state, [], "b", 0, 1)
          assert_equal 2, state.length
        end

        def test_multi_path
          table = tt ["/:a/d", "/b/c"]

          [
            [1, "/"],
            [2, "b"],
            [2, "/"],
            [1, "c"],
          ].inject([0]) { |state, (exp, sym)|
            table.move(state, [], sym, 0, sym.length)
            assert_equal exp, state.length
            state
          }
        end

        def test_match_data_ambiguous
          table = tt %w{
            /articles(.:format)
            /articles/new(.:format)
            /articles/:id/edit(.:format)
            /articles/:id(.:format)
          }

          sim = Simulator.new table

          memos = sim.memos "/articles/new"
          assert_equal 2, memos.length
        end

        ##
        # Identical Routes may have different restrictions.
        def test_match_same_paths
          table = tt %w{
            /articles/new(.:format)
            /articles/new(.:format)
          }

          sim = Simulator.new table

          memos = sim.memos "/articles/new"
          assert_equal 2, memos.length
        end

        def test_catchall
          table = tt %w{
            /
            /*unmatched_route
          }

          sim = Simulator.new table

          # matches just the /*unmatched_route
          memos = sim.memos "/test"
          assert_equal 1, memos.length

          # matches just the /
          memos = sim.memos "/"
          assert_equal 1, memos.length
        end

        private
          def ast(strings)
            parser = Journey::Parser.new
            asts   = strings.map { |string|
              memo = Object.new
              ast  = parser.parse string
              ast.each { |n| n.memo = memo }
              ast
            }
            Nodes::Or.new asts
          end

          def tt(strings)
            Builder.new(ast(strings)).transition_table
          end
      end
    end
  end
end
