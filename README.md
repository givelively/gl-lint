# Give Lively Lint runner

`GLLint` is a Ruby gem that handles running linters against specific files (e.g. just the changed files from a branch). It leverages `git`, `rubocop` and `eslint`

This is particularly useful for large projects where you don't want to lint all the files in the project.

At Give Lively, we add a file to `bin/lint` and have it call this gem to lint with autocorrect.

GLLint also adds a way to create a yaml file with all the currently configured rubocop rules (`.rubocop_rules.yml`). This is done via `bin/lint --write-rubocop-rules`. This file is useful to compare what changes when updating Rubocop rules, changing gems or Ruby versions.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'gl_lint', require: false
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install gl_lint

### bin/lint

Create a an executable `bin/lint` file with:

`touch bin/lint && chmod +x bin/lint`

Then add this to the file:

```ruby
#!/usr/bin/env ruby
require 'rubygems'
require 'gl_lint'

GLLint.call_cli(app_root: File.expand_path('..', __dir__))
```

Then run `bin/lint` to lint your changes.

Alternatively, if your project doesn't have JavaScript, add `linters: ['rubocop']`

```ruby
GLLint.call_cli(app_root: File.expand_path('..', __dir__),
                linters: ['rubocop'])
```

## Publishing gem to rubygems!

[Build the gem](http://guides.rubygems.org/make-your-own-gem/)

    gem build gl_lint.gemspec

[Push to rubygems](http://guides.rubygems.org/publishing/)

    gem push gl_lint-0.2.0.gem
