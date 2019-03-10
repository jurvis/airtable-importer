require_relative 'model/word'

require 'faraday'
require 'faraday_middleware'
require 'oxford_dictionary'
require 'dotenv'
require 'stemmify'

Dotenv.load

words = []
File.open("words.txt", "r").each_line do |line|
  words << line.chop.split("\n").first
end

words.each{|w| Word.import(w) }
