require 'dotenv/tasks'
require 'dotenv/load'
require 'rollbar'

require_relative 'pinboard_importer'

Rollbar.configure do |config|
  config.access_token = ENV['ROLLBAR_ACCESS_TOKEN']
end

task import_books: :dotenv do
  PinboardImporter.new.import_to_airtable
end
