@app_name = app_name

# clean file
run 'rm README.rdoc'

# .gitignore
run 'rm -rf .gitignore'
run 'wget https://raw.githubusercontent.com/Yosshi21/rails_template/master/.gitignore -P .gitignore'

# add to Gemfile
run 'rm -rf Gemfile'
file 'Gemfile', <<-CODE
source 'https://rubygems.org'

ruby '2.2.3'

# nokogiriインストールエラー回避のための環境変数設定
ENV['NOKOGIRI_USE_SYSTEM_LIBRARIES'] = 'YES'

gem 'rails', '4.2.4'
gem 'mysql2', '~>0.3.20'
gem 'sass-rails'
gem 'compass-rails', '~> 2.0.5'
gem 'uglifier', '>= 1.3.0'
# gem 'coffee-rails', '~> 4.1.0'
gem 'jquery-rails'
gem 'turbolinks'
gem 'jbuilder', '~> 2.0'
# gem 'slim-rails'
gem 'bootstrap-sass', '~> 3.3.5'
gem 'font-awesome-rails'
gem 'therubyracer', platforms: :ruby
gem 'newrelic_rpm'

gem 'sdoc', '~> 0.4.0', group: :doc

group :development do
  gem 'web-console', '~> 2.0'
  gem 'better_errors'
  gem 'annotate'
  gem 'quiet_assets'
  gem 'bullet' # N+1問題検出
  gem 'brakeman', :require => false # 静的解析
  # Deploy
  gem 'capistrano', '~> 3.4.0'
  gem 'capistrano-rails'
  gem 'capistrano-rbenv', require: false
  gem 'capistrano-bundler'
  gem 'capistrano3-unicorn'
end

group :development, :test do
  # PryでのSQLの結果を綺麗に表示
  gem 'hirb'
  gem 'hirb-unicode'

  gem 'byebug'
  gem 'spring'
  gem 'pry-rails'
  gem 'pry-byebug'
  gem 'awesome_print'
  gem 'rspec-rails'
  gem 'spring-commands-rspec'
  gem 'shoulda-matchers'
  gem 'database_cleaner'
  gem 'rubocop'
end

group :test do
    gem 'factory_girl_rails'
    gem 'simplecov', require: false #カバレッジ
    gem 'capybara'
end

group :production, :staging do
  gem 'unicorn' # 本番用Webサーバー
  gem 'exception_notification', :github => 'smartinez87/exception_notification' #エラー時にメールを送信する。メールサーバーを設定する必要あり https://github.com/smartinez87/exception_notification
  gem 'slack-notifier'
end

CODE

# install gems
run 'bundle install --path vendor/bundle'

# set Japanese locale
generate 'i18n_locale ja'
run 'rm -rf config/locales/ja.yml'
run 'wget https://raw.githubusercontent.com/Yosshi21/rails_template/master/config/locales/ja.yml -P config/locales/'

# set config/application.rb
application  do
  %q{
    # Set timezone
    config.time_zone = 'Tokyo'
    config.active_record.default_timezone = :local
    # 日本語化
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}').to_s]
    config.i18n.available_locales = %i(ja en)
    config.i18n.enforce_available_locales = true
    # generatorの設定
    config.generators do |g|
      g.orm :active_record
      g.template_engine :erb
      g.test_framework  :rspec, :fixture => true
      g.fixtures true
      g.fixture_replacement :factory_girl, :dir => "spec/factories"
      g.view_specs false
      g.controller_specs true #scaffoldのテスト生成用
      g.routing_specs false
      g.helper_specs false
      g.request_specs false # パブリックAPIのテスト用
      g.feature_specs true #結合テスト用
      g.acceptance_specs true #受入テスト用
      g.decorator_specs true
      g.assets false
      g.helper false
    end
    # libファイルの自動読み込み
    config.autoload_paths += %W(#{config.root}/lib)
    config.autoload_paths += Dir["#{config.root}/lib/**/"]
  }
end

# Rails 4.1でのsecrets.ymlの扱いの変更について要対応
run 'rm -rf config/initializers/secret_token.rb'
file 'config/initializers/secret_token.rb', <<-FILE
#{@app_name.classify}::Application.config.secret_key_base = ENV['SECRET_KEY_BASE'] || '#{`rake secret`}'
FILE

# application.js(turbolink setting)
run 'rm -rf app/assets/javascripts/application.js'
run 'wget https://raw.github.com/Yosshi21/rails_template/master/app/assets/javascripts/application.js -P app/assets/javascripts/'

# applocation.css(Bootstrap/Font-Awesome)
run 'rm -rf app/assets/stylesheets/application.css'
run 'wget https://raw.github.com/Yosshi21/rails_template/master/app/assets/stylesheets/application.scss -P app/assets/stylesheets/'

# For Bullet (N+1 Problem)
insert_into_file 'config/environments/development.rb',%(
# Rack::MiniProfiler.config.position = 'right'
  config.after_initialize do
    Bullet.enable = true
    Bullet.alert = true
    Bullet.bullet_logger = true
    Bullet.console = true
    Bullet.growl = false
    Bullet.rails_logger = true
    Bullet.airbrake = false
    Bullet.add_footer = true
  end
), after: 'config.assets.debug = true'

# Capistrano
Bundler.with_clean_env do
  run 'bundle exec cap install'

# Database
run 'rm -rf config/database.yml'
run 'wget https://raw.github.com/Yosshi21/rails_template/master/config/database.yml -P config/'
gsub_file 'config/database.yml', /APPNAME/, @app_name
run 'cp config/database.yml config/database.yml.sample'
gsub_file 'config/database.yml', /PASSWD/, @db_password
db_password = "'" + @db_password + "'"
Bundler.with_clean_env do
    run 'bundle exec rake RAILS_ENV=development db:create'
    run 'bundle exec rake RAILS_ENV=test db:create'
end

# Unicorn(App Server)
run 'mkdir config/unicorn'
run 'wget https://raw.github.com/Yosshi21/rails_template/master/config/unicorn/production.rb -P config/unicorn/'

# Rspec/Spring/Guard
# ----------------------------------------------------------------
# Rspec
generate 'rspec:install'

run 'bundle exec spring binstub --all'
run "echo '--color --drb -f d' > .rspec"

insert_into_file 'spec/ra_helper.rb',%(
  require 'simplecov'
  SimpleCov.start
  config.before :suite do
    DatabaseCleaner.strategy = :truncation
  end
  config.before :each do
    DatabaseCleaner.start
  end
  config.after :each do
    DatabaseCleaner.clean
  end
  config.before :all do
    FactoryGirl.reload
  end
  config.include FactoryGirl::Syntax::Methods
), after: 'RSpec.configure do |config|'

insert_into_file 'spec/spec_helper.rb',%(
  require 'factory_girl_rails'
  require 'simplecov'
  require 'shoulda-matchers'
  require 'capybara'
  require 'capybara/rspec'
  require 'capybara/poltergeist'
  Capybara.javascript_driver = :poltergeist
), after: "require 'rspec/rails'"

gsub_file 'spec/spec_helper.rb', "require 'rspec/autorun'", ''
end

# git init
# ----------------------------------------------------------------
git :init
git :add => '.'
git :commit => "-a -m 'first commit'"
