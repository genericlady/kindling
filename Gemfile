# frozen_string_literal: true

source "https://rubygems.org"

ruby ">= 3.2"

# GTK3 for GUI
gem "gtk3", "~> 4.2"
gem "gio2", "~> 4.2"
gem "gobject-introspection", "~> 4.2"

group :development, :test do
  # Testing
  gem "minitest", "~> 5.20"
  gem "minitest-reporters", "~> 1.6"
  gem "simplecov", "~> 0.22", require: false

  # Code quality
  gem "rubocop", "~> 1.50"
  gem "standard", ">= 1.35.1"

  # Build tools
  gem "rake", "~> 13.1"
end
