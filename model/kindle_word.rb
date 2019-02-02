class KindleWord
  attr_accessor :word, :books

  def initialize(word:, books:)
    @word = word
    @books = books
    @count = 0
  end

  def valid?
    return unless @word
    @word = KindleWord.transform_strip(@word)

    return !@word.include?(' ')
  end

  def self.transform_strip(word)
    stripped_word = word.strip.downcase
    stripped_word = stripped_word.sub(/(–|—|--).+/, '') # literary dashes should not be included
    stripped_word = stripped_word.sub(/\A[^[:alpha:]]*/, '') # turn e.g. "lackadaisical into lackadaisical
    stripped_word = stripped_word.sub(/[^[:alpha:]]*\Z/, '') # turn e.g. 'quandry."' into 'quandry'
    stripped_word = stripped_word.sub(/('|’)s\Z/, '') # e.g. kafka's => kafka
    stripped_word = stripped_word.sub("œ", "oe")

    stripped_word
  end
end