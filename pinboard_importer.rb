require 'nokogiri'
require 'faraday'
require 'pinboard'
require 'faraday_middleware'
require 'httply'

require_relative 'model/book'

class PinboardImporter
  def import_to_airtable 
    pinboard = Pinboard::Client.new(:token => ENV['PINBOARD_TOKEN'])
    posts = pinboard.posts(:tag => 'books').to_enum(:each).map { |bookmark| 
      if URI(bookmark.href).host =~ /\A(www\.)?amazon\.(com|sg)/
        uri = URI(bookmark.href)

        isbn_match = bookmark.href.match(/\/(\w{10})(\/|$|\||\?)/)
        if isbn_match.nil? or isbn_match[0].nil?
          puts bookmark.href
          Rollbar.log("URL Parse Error", bookmark.href)
        else
          create_record_from_isbn(isbn_match[0], bookmark)
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
    @clients[host] = Httply::Client.new(host: host)
  end
end
