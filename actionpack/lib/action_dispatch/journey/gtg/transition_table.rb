# frozen_string_literal: true

# :markup: markdown

require "action_dispatch/journey/nfa/dot"

module ActionDispatch
  module Journey # :nodoc:
    module GTG # :nodoc:
      class TransitionTable # :nodoc:
        include Journey::NFA::Dot

        attr_reader :memos

        DEFAULT_EXP = /[^.\/?]+/
        DEFAULT_EXP_ANCHORED = /\A#{DEFAULT_EXP}\Z/

        def initialize
          @stdparam_states = {}
          @regexp_states   = {}
          @string_states   = {}
          @accepting       = {}
          @memos           = Hash.new { |h, k| h[k] = [] }
        end

        def add_accepting(state)
          @accepting[state] = true
        end

        def accepting_states
          @accepting.keys
        end

        def accepting?(state)
          @accepting[state]
        end

        def add_memo(idx, memo)
          @memos[idx] << memo
        end

        def memo(idx)
          @memos[idx]
        end

        def eclosure(t)
          Array(t)
        end

        def move(states, continuous_states, full_string, start_index, end_index)
          return [[], []] if states.empty? && continuous_states.empty?

          next_states = []
          next_continuous_states = []

          length = end_index - start_index

          tok = if length == 1
                  case full_string.getbyte(start_index)
                  when 46
                    "."
                  when 47
                    "/"
                  when 63
                    "?"
                  end
                end || full_string.slice(start_index, length)
          token_matches_default_component = DEFAULT_EXP_ANCHORED.match?(tok)

          states.each { |s|
            # In the simple case of a "default" param regex do this fast-path and add all
            # next states.
            if token_matches_default_component && std_state = @stdparam_states[s]
              next_states << std_state
            end

            # When we have a literal string, we can just pull the next state
            if new_states = @string_states[s]
              next_states << new_states[tok] unless new_states[tok].nil?
            end

            # For regexes that aren't the "default" style, they may potentially not be
            # terminated by the first "token" [./?], so we need to continue to attempt to
            # match this regexp as well as any successful paths that continue out of it.
            # both paths could be valid.
            if new_states = @regexp_states[s]
              new_states.each { |re, v|
                # if we match, we can try moving past this
                next_states << v if !v.nil? && re.match?(tok)
              }

              # and regardless, we must continue accepting tokens and retrying this regexp. we
              # need to remember where we started as well so we can take bigger slices.
              next_continuous_states << [s, start_index].freeze
            end
          }

          continuous_states.each { |s, previous_start|
            if new_states = @regexp_states[s]
              curr_slice = full_string.slice(previous_start, end_index - previous_start)

              new_states.each { |re, v|
                # if we match, we can try moving past this
                next_states << v if !v.nil? && re.match?(curr_slice)
              }

              # and regardless, we must continue accepting tokens and retrying this regexp. we
              # need to remember where we started as well so we can take bigger slices.
              next_continuous_states << [s, previous_start].freeze
            end
          }

          [next_states, next_continuous_states]
        end

        def as_json(options = nil)
          simple_regexp = Hash.new { |h, k| h[k] = {} }

          @regexp_states.each do |from, hash|
            hash.each do |re, to|
              simple_regexp[from][re.source] = to
            end
          end

          {
            regexp_states:   simple_regexp,
            string_states:   @string_states,
            stdparam_states: @stdparam_states,
            accepting:       @accepting
          }
        end

        def to_svg
          svg = IO.popen("dot -Tsvg", "w+") { |f|
            f.write(to_dot)
            f.close_write
            f.readlines
          }
          3.times { svg.shift }
          svg.join.sub(/width="[^"]*"/, "").sub(/height="[^"]*"/, "")
        end

        def visualizer(paths, title = "FSM")
          viz_dir   = File.join __dir__, "..", "visualizer"
          fsm_js    = File.read File.join(viz_dir, "fsm.js")
          fsm_css   = File.read File.join(viz_dir, "fsm.css")
          erb       = File.read File.join(viz_dir, "index.html.erb")
          states    = "function tt() { return #{to_json}; }"

          fun_routes = paths.sample(3).map do |ast|
            ast.filter_map { |n|
              case n
              when Nodes::Symbol
                case n.left
                when ":id" then rand(100).to_s
                when ":format" then %w{ xml json }.sample
                else
                  "omg"
                end
              when Nodes::Terminal then n.symbol
              else
                nil
              end
            }.join
          end

          stylesheets = [fsm_css]
          svg         = to_svg
          javascripts = [states, fsm_js]

          fun_routes  = fun_routes
          stylesheets = stylesheets
          svg         = svg
          javascripts = javascripts

          require "erb"
          template = ERB.new erb
          template.result(binding)
        end

        def []=(from, to, sym)
          case sym
          when String, Symbol
            to_mapping = @string_states[from] ||= {}
            # account for symbols in the constraints the same as strings
            to_mapping[sym.to_s] = to
          when Regexp
            if sym == DEFAULT_EXP
              @stdparam_states[from] = to
            else
              to_mapping = @regexp_states[from] ||= {}
              # we must match the whole string to a token boundary
              to_mapping[/\A#{sym}\Z/] = to
            end
          else
            raise ArgumentError, "unknown symbol: %s" % sym.class
          end
        end

        def states
          ss = @string_states.keys + @string_states.values.flat_map(&:values)
          ps = @stdparam_states.keys + @stdparam_states.values
          rs = @regexp_states.keys + @regexp_states.values.flat_map(&:values)
          (ss + ps + rs).uniq
        end

        def transitions
          @string_states.flat_map { |from, hash|
            hash.map { |s, to| [from, s, to] }
          } + @stdparam_states.map { |from, to|
            [from, DEFAULT_EXP_ANCHORED, to]
          } + @regexp_states.flat_map { |from, hash|
            hash.map { |s, to| [from, s, to] }
          }
        end
      end
    end
  end
end
