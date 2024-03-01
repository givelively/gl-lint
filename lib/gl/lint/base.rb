#!/usr/bin/env ruby
require 'optparse'
LINTERS = %w[rubocop prettier].freeze

TARGET_FILE_OPTS = [
  ['--changed', '-c', 'Lints uncommitted changes (default)'],
  ['--staged', '-s', 'Lints only staged files'],
  ['--branch', '-b', 'Lints any files changed in the branch'],
  ['--all', '-a', 'Lints all files']
].freeze

options = { linter: LINTERS, unsafe_fix: ENV['UNSAFE_LINT'] == 'true' }
# rubocop:disable Metrics/BlockLength
OptionParser.new do |parser|
  TARGET_FILE_OPTS.each do |args|
    parser.on(*args) do
      raise "You can't pass multiple 'target files' options!" if options[:target_files]

      options[:target_files] = args.first
    end
  end

  parser.on('--rubocop', 'Lints only with rubocop') do
    raise "This project doesn't support rubocop" unless LINTERS.include?('rubocop')

    options[:linter] = ['rubocop']
  end

  parser.on('--prettier', 'Lints only with prettier') do
    raise "This project doesn't support rubocop" unless LINTERS.include?('prettier')
    raise "You can't pass both --rubocop and --prettier" if options[:linter] == ['rubocop']

    options[:linter] = ['prettier']
  end

  parser.on('--no-fix', 'Does not auto-fix') do
    options[:no_fix] = true
  end

  parser.on('--unsafe-fix', 'Rubocop fixes with unsafe option (also can be set with UNSAFE=true)') do
    options[:unsafe_fix] = true
  end

  parser.on('--list-files', 'Prints out files that would be linted (dry run)') do
    options[:list_target_files] = true
  end

  parser.on_tail('-h', '--help', 'Show this message') do
    puts parser
    puts "\nExamples:"
    puts '    bin/lint                         -- Lints uncommitted changes (default)'
    puts '    bin/lint --branch                -- Lints files changed on current branch'
    puts "    bin/lint spec/rails_helper.rb    -- Lints 'spec/rails_helper.rb'"
    puts ''
    exit
  end
end.parse!
# rubocop:enable Metrics/BlockLength

# Enable passing in filenames to lint
if ARGV.any?
  options[:filenames] = ARGV
  puts "passed files: #{options[:filenames]}"

  raise "Passed both 'filenames' and 'target files': #{options[:target_files]}" if options[:target_files]
end

NON_RB_RUBY_FILES = %w[Gemfile Rakefile config.ru
                       bin/bundle bin/lint bin/rubocop bin/setup bin/update].freeze

# rubocop:disable Style/MixinUsage
require 'fileutils'
include FileUtils
# rubocop:enable Style/MixinUsage

# path to your application root.
APP_ROOT = File.expand_path('..', __dir__)

@linter_failures = []

def run_linter(*args)
  return if system(*args)

  @linter_failures << "\n== Command #{args} failed =="
end

def parse_git_output(str)
  # Return nil if the file is deleted
  return nil if str.start_with?(/\s?D\s/)

  if str.match?(/^R/)
    # If renamed, grab the renamed filename (which is the second filenamename in the list)
    str.split(/(->)|(\t+)/).last
  else
    # Otherwise just grab the filename
    str.gsub(/^\s?\S\S?\s+/, '')
  end.strip
end

# rubocop:disable Metrics
def filenames_for_target_files(target_files)
  case target_files
  when '--branch'
    branch = `git symbolic-ref --short HEAD`.strip
    main_branch = 'origin/main' # We need to use origin/main or the github action fails
    puts "linting changed files between '#{main_branch}' > '#{branch}'\n\n"
    `git diff --merge-base --name-status #{main_branch} #{branch}`.split("\n")
  when '--staged'
    # staged files have the change as the first character
    `git status -s`.split("\n").select { |s| s.start_with?(/^\w/) }
  when '--all'
    nil
  else
    # Get just the filenames of the changed files
    `git status -s`.split("\n")
  end&.map { |s| parse_git_output(s) }
    &.compact
end

def lint_ruby_files(linter, target_files, no_fix, rubocop_files, list_only, unsafe_fix)
  return unless linter.include?('rubocop')

  if target_files != '--all' && rubocop_files&.none?
    puts "\nNo ruby files to lint!"
    return
  end

  puts "\n== Linting ruby files =="
  puts rubocop_files, ''
  return if list_only

  rubocop_arg = if no_fix
                  ''
                else
                  unsafe_fix ? '-A' : '-a'
                end
  puts 'Rubcop is running in unsafe mode' if rubocop_arg == '-A'
  run_linter(
    'bundle exec rubocop --format quiet -c .rubocop.yml ' \
    "#{rubocop_arg} #{rubocop_files&.join(' ')}"
  )
end

# rubocop:enable Metrics

def lint_prettier_files(linter, target_files, no_fix, prettier_files, list_only)
  return unless linter.include?('prettier')

  if target_files != '--all' && prettier_files&.none?
    puts "\nNo prettier_files to lint!"
    return
  end
  puts "\n== Linting prettier files files =="
  puts prettier_files, ''
  return if list_only

  # Need to manually call eslint, the package.json script specifies the folders to lint
  prettier_command = no_fix ? 'eslint' : 'eslint --fix'
  run_linter("yarn run #{prettier_command} #{prettier_files&.join(' ')}")
end

chdir APP_ROOT do
  filenames = options[:filenames] || filenames_for_target_files(options[:target_files])

  if filenames
    rubocop_files = filenames.grep(/\.(rb|rake|gemspec)\z/)
    rubocop_files += filenames & NON_RB_RUBY_FILES

    prettier_files = filenames.grep(/\.(js|jsx|json|css|md)\z/)
  end

  lint_ruby_files(options[:linter], options[:target_files], options[:no_fix], rubocop_files,
                  options[:list_target_files], options[:unsafe_fix])

  lint_prettier_files(options[:linter], options[:target_files], options[:no_fix], prettier_files,
                      options[:list_target_files])
end
puts '' # Add a little bit of space after

abort(@linter_failures.join("\n")) if @linter_failures.any?
