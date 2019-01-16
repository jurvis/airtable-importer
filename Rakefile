require 'dotenv/tasks'
require 'dotenv/load'
require 'rollbar'

require_relative 'importer'

Rollbar.configure do |config|
  config.access_token = ENV['ROLLBAR_ACCESS_TOKEN']
end

task import_books: :dotenv do
  BookImport.new.pinboard
end