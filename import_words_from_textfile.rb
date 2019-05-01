require_relative 'model/word'
require_relative 'model/kindle_word'

require 'faraday'
require 'faraday_middleware'
require 'oxford_dictionary'
require 'dotenv'
require 'stemmify'

Dotenv.load

words = []
File.open("words.txt", "r").each_line do |line|
  kw = KindleWord.new(
    word: line.chop.split("\n").first,
    books: ["The 48 Laws of Power"]
  )
  words << kw
end

words = words.select { |highlight|
  highlight.valid? && Word.is_unique?(highlight.word)
}.each {|word|
  word.transform_root_word
}

for kindle_word in words do
  puts "Importing #{kindle_word.word} to AirTable..."
  Word.import(kindle_word.word)
end