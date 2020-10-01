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
        doc = client_for("#{uri.scheme}://#{uri.hostname}").get(uri.path).body

        prop_string = doc.css("#detailBullets_feature_div > ul > li:nth-child(3)").map{ |node| node.text.gsub(/\s+/, "") }.first
        if prop_string.nil?
          Rollbar.log('parseError', bookmark.href)
        end
        
        isbn = prop_string.match(/(ISBN|ASIN)(-13|-10)?:\s*\s*(\w{10,13})/)
        if isbn.nil? or isbn[3].nil?
          Rollbar.log('parseError', bookmark.href)
        else
          create_record_from_isbn(isbn[3], bookmark)
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
