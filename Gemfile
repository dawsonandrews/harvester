source 'https://rubygems.org'

ruby '2.3.3'

gem 'http'
gem 'activesupport'
gem 'dotenv'
gem 'sinatra'

# Serve with puma
gem 'puma'

group :development do
  gem 'shotgun'
  gem 'guard'
  gem 'guard-rspec', require: false
  gem 'terminal-notifier', '~> 1.7.1'
  gem 'terminal-notifier-guard', '~> 1.7.0'
end

group :development, :test do
  gem 'rspec'
end

group :test do
  gem 'rack-test', '~> 0.6.3'
end
