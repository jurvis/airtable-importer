require 'airrecord'
require 'dotenv/load'
require 'oxford_dictionary'

Airrecord.api_key = ENV['AIRTABLE_API_KEY']

class Word < Airrecord::Table
  self.base_key = ENV['AIRTABLE_WORDS_BASE_KEY']
  self.table_name = "WORDS"

  def self.import(word)
    all = Hash[self.all.group_by{|obj| obj["Word"]}.map{ |(word, objs)| [word, objs.first] }]

    if existing = all[word]
    else
      word = self.new("Word" => word)
      word["Definition"] = word.definition 
      word["Similar Words"] = word.similar_words 
      word["Examples"] = word.examples
      word["Audio"] = word.audio_url

      word.create
    end
  end

  def examples
    return "" unless word_query_response && word_query_response.lexical_entries.first.entries.first.senses.first 
    word_query_response.lexical_entries.first.entries.first.senses.first.examples.map{|e| e.text}.join("\n")
  end

  def definition
    return "" unless word_query_response && word_query_response.lexical_entries.first.entries.first.senses.first
    word_query_response.lexical_entries.first.entries.first.senses.first.definitions.first
  end

  def audio_url
    return "" unless word_query_response && word_query_response.lexical_entries.first.pronunciations
    word_query_response.lexical_entries.first.pronunciations.first.audio_file
  end
   
  def similar_words
    return "" unless word_synonyms_response && word_synonyms_response.lexical_entries.first.entries.first.senses.first
    word_synonyms_response.lexical_entries.first.entries.first.senses.first.synonyms.map{|s| s.text}.join(", ")
  end

  private
  def word_synonyms_response
    @word_synonyms_response ||= begin 
      dictionary_connection.entry_antonyms_synonyms(self["Word"])
    rescue => error
      puts "Unable to find #{self["Word"]}"
    end 
  end

  def word_query_response
    @word_query_response ||= begin
      dictionary_connection.entry(self["Word"])
    rescue => error
      puts "Unable to find #{self["Word"]}"
    end
  end

  def dictionary_connection
    @@client ||= OxfordDictionary::Client.new(app_id: ENV['OXFORD_DICT_APP_ID'], app_key: ENV['OXFORD_DICT_APP_KEY'])
  end
end