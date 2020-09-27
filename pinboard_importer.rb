require 'nokogiri'
require 'faraday'
require 'pinboard'
require 'faraday_middleware'

require_relative 'model/book'

class PinboardImporter
  def import_to_airtable 
    pinboard = Pinboard::Client.new(:token => ENV['PINBOARD_TOKEN'])
    posts = pinboard.posts(:tag => 'books').to_enum(:each).map { |bookmark| 
      if URI(bookmark.href).host =~ /\A(www\.)?amazon\.(com|sg)/
        uri = URI(bookmark.href)
        text = client_for("#{uri.scheme}://#{uri.hostname}").get(uri.path).body
        doc = Nokogiri::HTML(text)
        isbn = doc.css("#detailBullets_feature_div > ul > li:nth-child(3)").map{ |node| node.text.gsub(/\s+/, "").split(":")[1] }.first
        unless isbn.nil?
          create_record_from_isbn(isbn, bookmark)
        else
          Rollbar.log('parseError', bookmark.href)
        end
      elsif bookmark.href =~ /goodreads\.com/
        uri = URI(bookmark.href)
        text = client_for("#{uri.scheme}://#{uri.hostname}").get(uri.path).body
        doc = Nokogiri::HTML(text)
        create_record_from_isbn(doc.at('meta[property="books:isbn"]')["content"], bookmark.hash)
      end
    }.compact
  end

  def create_record_from_isbn(isbn, bookmark)
    endorsements = bookmark.extended.split(/\s*,\s*/)
    Book.new("ISBN" => isbn).populate_from_goodreads(endorsements)
  end

  def client_for(host)
    @clients ||= {}
    return @clients[host] if @clients[host]
    @clients[host] ||= Faraday.new(:url => host) do |b|
      b.request :retry, max: 10, interval: 1, interval_randomness: 2, backoff_factor: 2
      b.use FaradayMiddleware::FollowRedirects
      b.adapter :net_http_persistent
      b.headers["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3359.117 Safari/537.36"
    end
  end
end
