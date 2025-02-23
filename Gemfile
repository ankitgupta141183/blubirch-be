source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }



# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 6.0.2', '>= 6.0.2.2'
# Use postgresql as the database for Active Record
gem 'pg', '>= 0.18', '< 2.0'
# Use Puma as the app server
gem 'puma', '~> 4.1'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
# gem 'jbuilder', '~> 2.7'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use Active Model has_secure_password
# gem 'bcrypt', '~> 3.1.7'

gem 'carrierwave', '~> 2.0'
gem "fog-aws"

gem "activerecord-import", '1.4.1'
gem 'redis', '4.1.4'

gem 'sidekiq', '6.0.7'

gem 'ancestry'
# Use Active Storage variant
# gem 'image_processing', '~> 1.2'

# Use devise for authentication and JWT token based auth
gem 'devise'
gem 'devise-jwt', '~> 0.6.0'
gem "logidze"

gem 'rest-client', '~> 2.1'


gem 'aws-sdk-core', '~> 3', require: 'aws-sdk'
gem 'aws-sdk-resources', '~> 3', require: 'aws-sdk-resources'
gem 'aws-sdk', '~> 3', require: 'aws-sdk'

gem "paranoia"

# pagination
gem 'kaminari'

gem 'time_difference'

# ActiveModelSerializers brings convention over configuration to your JSON generation.
gem 'active_model_serializers', '~> 0.10.0'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.4.2', require: false

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin AJAX possible
gem 'rack-cors'

gem 'whenever', require: false

gem "roo", "~> 2.8.0"

gem 'scout_apm'

# merging query for forward-reverse
gem 'active_record_union'

group :development, :test do
  gem 'rubocop-rails', require: false
  gem "rubycritic", require: false
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  # to generate fake data
  gem 'faker'
  gem 'awesome_print' 
end

group :development do
  gem 'listen', '>= 3.0.5', '< 3.2'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
  gem 'capistrano',                 require: false
  gem 'capistrano-rvm',             require: false
  gem 'capistrano-rails',           require: false
  gem 'capistrano-bundler','2.1.0', require: false
  gem 'capistrano3-puma',           require: false
  gem 'pry'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]

# APM to monitor performance
gem 'pg_search', '~> 2.3', '>= 2.3.6'
gem 'shorturl'
gem 'prawn'
gem 'prawn-table'
gem 'rbnacl', '7.1.1'