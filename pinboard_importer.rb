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
        isbn = get_isbn_from_amazon(bookmark.href)

        if isbn.nil?
          Rollbar.log("URL Parse Error", bookmark.href)
        else
          create_record_from_isbn(isbn, bookmark)
        end
      elsif bookmark.href =~ /goodreads\.com/
        create_record_from_isbn(get_isbn_from_goodreads(bookmark.href), bookmark)
      end
    }.compact
  end

  def get_isbn_from_goodreads(url)
    uri = URI(url)
    text = client_for("#{uri.scheme}://#{uri.hostname}").get(uri.path).body
    return text.at('meta[property="books:isbn"]')["content"]
  end

  def get_isbn_from_amazon(url)
    isbn_match = url.match(/\/(\w{10})(\/|$|\||\?)/)
    if isbn_match.nil? or isbn_match[0].nil?
      return nil
    else
      return isbn_match[0].gsub!(/[^0-9A-Za-z]/, '')
    end
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
