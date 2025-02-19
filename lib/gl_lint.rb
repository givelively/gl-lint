require 'gl_lint/cli'
require 'gl_lint/file_selector'
require 'gl_lint/linter'
require 'gl_lint/export_rubocop'

module GLLint
  class << self
    def call_cli(app_root:, default_target: nil, linters: nil)
      options = GLLint::CLI.parse(app_root:, linters:, default_target:)
      puts 'Options: ', options, '' if options[:verbose]

      call(**options.except(:verbose, :default_target))
    end

    def call(app_root:, write_rubocop_rules: false, no_fix: false, list_only: false,
             unsafe_fix: false, linters: nil, target_files: nil, filenames: nil)

      Dir.chdir(app_root) do
        if write_rubocop_rules
          GLLint::ExportRubocop.write_rules(app_root)
        else
          lint_strategy = lint_strategy_from_options(no_fix:, list_only:, unsafe_fix:)
          GLLint::Linter.new.lint(linters:, target_files:, filenames:, lint_strategy:)
        end
      end
    end

    private

    def lint_strategy_from_options(no_fix: false, list_only: false, unsafe_fix: false)
      return :list_only if list_only
      return :no_fix if no_fix

      unsafe_fix ? :unsafe_fix : :fix
    end
  end
end
