require 'faraday'

require_relative 'model/kindle_word'

class ReadwiseImporter

  def import_words
    ReadwiseImporter.highlights.map { |_author, book, _asin, _id, text, _note_id, note|
      KindleWord.new(
        word: text,
        books: [book]
      )
    }.select { |highlight|
      highlight.valid?
    }
  end

  private

  def self.highlights
    JSON.parse(Readwise.get("/munger").body)["data"].flat_map { |source|
      source["highlights"].map { |highlight|
        [source["author"], source["source"], nil, nil, highlight["highlight"], nil, highlight["note"]]
      }
    }
  end
end

Readwise = Faraday.new(:url => "https://readwise.io") do |b|
  b.request :retry, max: 10, interval: 1, interval_randomness: 2, backoff_factor: 2
  b.use FaradayMiddleware::FollowRedirects
  b.adapter :net_http_persistent
  # get this from the chrome inspector, just a cookie to readwise
  b.headers[:Cookie] = "sessionid=\"\"; accessToken=#{ENV['READWISE_ACCESS_TOKEN']}; rwsessionid=#{ENV['READWISE_SESSION_ID']};"
end
