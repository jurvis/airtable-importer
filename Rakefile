require 'dotenv/tasks'
require 'dotenv/load'
require 'rollbar'

require_relative 'pinboard_importer'
require_relative 'readwise_importer'
require_relative 'kindle_importer'

Rollbar.configure do |config|
  config.access_token = ENV['ROLLBAR_ACCESS_TOKEN']
end

task import_books: :dotenv do
  PinboardImporter.new.import_to_airtable
end

task import_vocab: :dotenv do
  words = ReadwiseImporter.new.import_words
  for kindle_word in words do
    puts kindle_word.word
  end
  # KindleImporter.new.import_words_to_airtable(words)
end
