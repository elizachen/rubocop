# frozen_string_literal: true

module RuboCop
  module Cop
    module Style
      # This cop checks for extra underscores in variable assignment.
      #
      # @example
      #   # bad
      #   a, b, _ = foo()
      #   a, b, _, = foo()
      #   a, _, _ = foo()
      #   a, _, _, = foo()
      #
      #   # good
      #   a, b, = foo()
      #   a, = foo()
      #   *a, b, _ = foo()  => We need to know to not include 2 variables in a
      #   a, *b, _ = foo()  => The correction `a, *b, = foo()` is a syntax error
      #
      #   # good if AllowNamedUnderscoreVariables is true
      #   a, b, _something = foo()
      class TrailingUnderscoreVariable < Cop
        include SurroundingSpace

        MSG = 'Do not use trailing `_`s in parallel assignment. ' \
              'Prefer `%s`.'.freeze
        UNDERSCORE = '_'.freeze

        def on_masgn(node)
          range = unneeded_range(node)

          return unless range

          good_code = node.source
          offset = range.begin_pos - node.source_range.begin_pos
          good_code[offset, range.size] = ''

          add_offense(node, location: range, message: format(MSG, good_code))
        end

        def autocorrect(node)
          range = unneeded_range(node)

          lambda do |corrector|
            corrector.remove(range) if range
          end
        end

        private

        def find_first_offense(variables)
          first_offense = find_first_possible_offense(variables.reverse)

          return unless first_offense
          return if splat_variable_before?(first_offense, variables)

          first_offense
        end

        def find_first_possible_offense(variables)
          variables.reduce(nil) do |offense, variable|
            var, = *variable
            var, = *var
            if allow_named_underscore_variables
              break offense unless var == :_
            else
              break offense unless var.to_s.start_with?(UNDERSCORE)
            end

            variable
          end
        end

        def splat_variable_before?(first_offense, variables)
          # Account for cases like `_, *rest, _`, where we would otherwise get
          # the index of the first underscore.
          first_offense_index = reverse_index(variables, first_offense)

          variables[0...first_offense_index].any?(&:splat_type?)
        end

        def reverse_index(collection, item)
          collection.size - 1 - collection.reverse.index(item)
        end

        def allow_named_underscore_variables
          @allow_named_underscore_variables ||=
            cop_config['AllowNamedUnderscoreVariables']
        end

        def unneeded_range(node)
          left, right = *node
          variables = *left
          first_offense = find_first_offense(variables)

          return unless first_offense

          if unused_variables_only?(first_offense, variables)
            return left_side_range(left, right)
          end

          if Util.parentheses?(left)
            return range_for_parentheses(first_offense, left)
          end

          range_between(
            first_offense.source_range.begin_pos,
            node.loc.operator.begin_pos
          )
        end

        def unused_variables_only?(offense, variables)
          offense.source_range == variables.first.source_range
        end

        def left_side_range(left, right)
          range_between(
            left.source_range.begin_pos, right.source_range.begin_pos
          )
        end

        def range_for_parentheses(offense, left)
          range_between(
            offense.source_range.begin_pos - 1,
            left.loc.expression.end_pos - 1
          )
        end
      end
    end
  end
end
