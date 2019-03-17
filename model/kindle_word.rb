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

  def transform_root_word
    if word_is_inflected
      puts "Inflected Word! Changing #{@word} to #{inflected_word}"
      @word = inflected_word
    end
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

  def word_is_inflected
    inflected_word != @word
  end

  def inflected_word
    return @word unless lemmatron_response
    lemmatron_response.lexical_entries.first.inflection_of.first.text
  end

  private
  def lemmatron_response
    @lemmatron_response ||= begin
      dictionary_connection.inflection(@word)
    rescue => error
      puts "Unable to find root of #{@word}"
    end
  end

  def dictionary_connection
    @@client ||= OxfordDictionary::Client.new(app_id: ENV['OXFORD_DICT_APP_ID'], app_key: ENV['OXFORD_DICT_APP_KEY'])
  end
end