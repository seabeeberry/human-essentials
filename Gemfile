source "https://rubygems.org"

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

###### BASIC FRAMEWORKS ######

# User management and login workflow.
gem "devise", '>= 4.7.1'
# Postgres database adapter.
gem "pg", "~> 1.5.9"
# Web server.
gem "puma"
# Rails web framework.
gem "rails", "~> 8.0.2"

###### MODELS / DATABASE #######

# These two gems are used to hook into ActiveStorage to store blobs in Azure Storage Service.
# gem 'azure-storage', '~> 0.15.0.preview', require: false
# For ActiveStorage on AWS
gem 'aws-sdk-s3', require: false
gem 'azure-storage-blob'
# Adds soft delete functionality for models.
gem 'discard', '~> 1.3'
# Treats attributes like money, which knows about dollars and cents.
gem "money-rails"
# Tracks history / audits models.
gem "paper_trail"
# Associates users with roles.
gem "rolify", "~> 6.0"
# Enforces "safe" migrations.
gem "strong_migrations"
# used in events
gem 'dry-struct'
# Use solid_cache as a cache store
gem "solid_cache", "~> 1.0"

##### JAVSCRIPT/CSS/ASSETS #######

# Bootstrap is a library for HTML, CSS and JS.
gem 'bootstrap', '~> 5.2'
# SASS CSS framework (nested selectors, variables, etc.)
gem "sass-rails"
# Used to verify that the user is a human.
gem "recaptcha"
# Hotwire for SPA like without much JS
gem "turbo-rails"
# Sprinkle a little JS to add interactivity
gem "stimulus-rails"
# Use JS import maps to manage JS without transpiling or bundling.
gem "importmap-rails", "~> 2.1"

##### VIEWS/CONTROLLERS #####

# Adds filter support to models and views.
gem "filterrific"
# Generates JSON structures via a builder interface.
gem "jbuilder"
# Pagination of models for use in views.
gem "kaminari"
# Prevents cookie overflow errors when storing large flash messages.
gem 'memflash'
# Web-based authorization framework.
gem "omniauth"
# Required to avoid authentication issues with Rails.
gem "omniauth-rails_csrf_protection"
# Allow login via Google.
gem "omniauth-google-oauth2"
# Generate PDFs as views.
gem "prawn-rails"
# Reduces boilerplate HTML code when writing forms.
gem "simple_form"

##### ADDITIONAL FUNCTIONS #####

# External service that monitors exceptions and reports them to Slack or e-mail.
gem "bugsnag"
# Runs jobs asynchronously using the database as a queue.
gem 'delayed_job_active_record'
# UI for showing job status.
gem 'delayed_job_web'
# Sends invitations via e-mail for new users.
gem "devise_invitable"
# Environment variable and configuration management.
gem "dotenv-rails"
# Feature flagging and management.
gem "flipper"
gem "flipper-active_record"
gem "flipper-ui"
# Calculates latitude and longitude from an address.
gem "geocoder"
# Generate .ics calendars for use with Google Calendar
gem 'icalendar', require: false
# JSON Web Token encoding / decoding (e.g. for links in e-mails)
gem "jwt"
# Use Newrelic for logs and APM
gem "newrelic_rpm"
# Used to manage periodic cron-like jobs
gem "clockwork"
# Speed up app boot time by caching expensive operations
gem 'bootsnap', require: false

##### DEPENDENCY PINS ######
# These are gems that aren't used directly, only as dependencies for other gems.
# Technically they don't need to be in this Gemfile at all, but we are pinning them to
# specific versions for compatibility reasons.
gem "nokogiri", ">= 1.10.4"
gem "sprockets", "~> 4.2.2"
gem "prawn", "~> 2.4.0"
gem "matrix" # Used by prawn
gem "ttfunk", "~>1.7.0"

group :production, :staging do
  # Reduce the noise of logs and include custom fields to it for easier access
  gem 'lograge'
  # JS compression for deployed environments.
  gem 'terser'
end

group :development, :test, :staging do
  # Generate models based on factory definitions.
  gem 'factory_bot_rails'
  # Ensure the database is in a clean state on every test.
  gem "database_cleaner-active_record", '~> 2.2'
  # Generate fake data for use in tests.
  gem 'faker'
end

group :development, :test do
  # Command line tool for better object printing.
  gem "awesome_print"
  # Scan for vulnerabilities and other static analysis.
  gem "brakeman"
  # Re-run specs when files change.
  gem "guard-rspec"
  # Split tests in a suite across multiple runners.
  gem "knapsack_pro"
  # Show core documentation in command line.
  gem "pry-doc"
  # Rails plugin for command line.
  gem "pry-rails"
  # Connect to a remotely running command line instance.
  gem "pry-remote"
  # Add-on for command line to create a simple debugger.
  gem "pry-nav"
  # Debugger which supports rdbg and Shopify Ruby LSP VSCode extension
  gem "debug", ">= 1.0.0"
  # RSpec behavioral testing framework for Rails.
  gem "rspec-rails", "~> 8.0.0"
  # Static analysis / linter.
  gem "rubocop"
  # Rails add-on for static analysis.
  gem 'rubocop-performance'
  gem "rubocop-rails", "~> 2.25.1"
  # More concise test ("should") matchers
  gem "shoulda-matchers", "~> 6.5"
  # Default rules for Rubocop.
  gem "standard", "~> 1.50"
  gem "standard-rails"
  gem "standard-performance"
  # Erb linter.
  gem "erb_lint"
end

group :development do
  # Show database columns and indexes inside files.
  gem "annotaterb"
  # Used as a dependency for better_errors.
  gem "binding_of_caller"
  # Show a better error page on development, including a REPL.
  gem "better_errors"
  # Detect N+1 and other slow queries.
  gem "bullet"
  # Run multiple processes from a Procfile (web, jobs, etc.)
  gem 'foreman'
  # Open sent e-mails in the browser instead of trying to send to a real mail server.
  gem "letter_opener"
  # Used as a dependency for Guard.
  gem "listen", "~> 3.9.0"
  # Generate a diagram based on Rails models.
  gem "rails-erd"
  # Allows to create a console in the browser.
  gem "web-console"
  # Middleware that displays speed badge for every HTML page
  gem "rack-mini-profiler"
  # Adds memory profiling to rack-mini-profiler
  gem "memory_profiler"
  # Adds call-stack profiling flamegraphs to rack-mini-profiler
  gem "stackprof"
end

group :test do
  # Test using browsers.
  gem "capybara", "~> 3.40"
  # Create screenshots when doing browser tests.
  gem "capybara-screenshot"
  # Generate Capybara tests in the browser and debug them.
  gem 'magic_test'
  # Can ensure that text appears before other text.
  gem "orderly", "~> 0.1"
  # Bring back deprecated controller tests.
  gem "rails-controller-testing"
  # Show code coverage.
  gem 'simplecov'
  # Mock HTTP requests and ensure they are not called during tests.
  gem "webmock", "~> 3.25"
  # Interface capybara to chrome headless
  gem "cuprite"
  # Read PDF files for tests
  gem "pdf-reader"
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem

# This 'if' may seem redundant but for some reason it is necessary to suppress
# a warning on non (Windows or JRuby) platforms.
if %w(mingw mswin x64_mingw jruby).include?(RUBY_PLATFORM)
  gem "tzinfo-data", "~> 1.2", platforms: %i(mingw mswin x64_mingw jruby)
end
