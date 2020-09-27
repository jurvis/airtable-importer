require 'hashdiff'
require 'airrecord'
require 'goodreads'
require 'dotenv/load'

Airrecord.api_key = ENV['AIRTABLE_API_KEY']

class Book < Airrecord::Table
  class Endorser < Airrecord::Table
    self.base_key = ENV['AIRTABLE_BOOKS_BASE_KEY']
    self.table_name = "Endorsers"
  end
  self.base_key = ENV['AIRTABLE_BOOKS_BASE_KEY']
  self.table_name = "Books"

  has_many :endorsements, class: 'Book::Endorser', column: 'Endorsements'

  GOODREADS_BLACKLIST = %w(
    to-read favorites currently-reading owned
    series favourites re-read owned-books
    books-i-own wish-list si audiobook
    book-club ebook kindle to-buy
  )

  GOODREADS_MERGE = {
    "Non-fiction" => "Nonfiction",
    "Classic" => "Classics",
    "Cookbook" => "Cooking",
    "Cookbooks" => "Cooking",
    "Biography" => "Memoir",
    "Biographies" => "Memoir",
    "Autobiography" => "Memoir",
    "Auto-biography" => "Memoir",
    "Sci-fi" => "Science Fiction",
    "Scifi" => "Science Fiction",
    "Management" => "Leadership",
    "Self-help" => "Personal Development",
    "Selfhelp" => "Personal Development",
    "Personal-development" => "Personal Development",
    "Self-improvement" => "Personal Development",
    "Science-fiction" => "Science Fiction",
    "Ya" => "Young-adult",
    "Tech" => "Technology",
    "Young-adult" => "Young Adult",
    "Computer-science" => "Programming",
    "Investing" => "Economics",
    "Fitness" => "Health",
    "Food" => "Cooking",
    "Finance" => "Economics",
    "Software" => "Programming",
    "Literature" => "Classics",
  }

  CATEGORIES = [
    "Business", "Psychology", "Science", "Personal Development", "Philosophy",
    "History", "Fiction", "Memoir", "Leadership", "Classics", "Economics",
    "Cooking", "Programming", "Health", "Politics", "Technology", "Science Fiction",
    "Entrepreneurship", "Design", "Writing", "Fantasy", "Young Adult", "Nonfiction",
  ]

  def goodreads_id
    query = self["ISBN"] if self["ISBN"]
    query ||= "\"#{self["Title"]}\""

    search = goodreads_client.search_books(query)
    if search.results.respond_to?(:work)
      matches = [search.results.work].flatten

      if self["author"]
        best_match = matches.find { |match|
          character_difference?(match["best_book"]["author"]["name"], self["author"])
        }
      end

      best_match ||= matches.first
      return unless best_match
      best_match.best_book.id
    end
  end

  def goodreads_book
    @book ||= begin
      id = goodreads_id
      return unless id
      goodreads_client.book(id)
    end
  end

  def goodreads_categories(n = 5)
    popular = goodreads_book.popular_shelves
    return [] if popular.blank?

    shelves = popular.shelf
    return [] unless shelves.first.respond_to?(:name)

    shelves.map(&:name).reject { |name|
      GOODREADS_BLACKLIST.include?(name)
    }.first(n).map { |name|
      name = name.capitalize
      name = GOODREADS_MERGE[name] if GOODREADS_MERGE[name]
      (CATEGORIES.include?(name) && name) || nil
    }.compact.uniq
  end

  def populate_from_goodreads(endorsements, prevent_duplicates_from: Book.all)
    book = goodreads_book

    unless book
      $stderr.puts "Unable to find book #{self["Title"]}"
      Rollbar.log('searchError', self["Title"])
      return
    end

    before = self.serializable_fields
    self["Title"] = book.title
    self["ISBN"] = book.isbn13 || self["ISBN"]
    self["Publication Year"] = book.work.original_publication_year.to_s || book.publication_year.to_s
    self["Goodreads Rating"] = book.average_rating.to_f
    self["Pages"] = book.num_pages
    authors = [book.authors.author].flatten
    self["Author"] = authors.first.name
    self["Categories"] = goodreads_categories.sort
    self["Goodreads Ratings"] = book.work.ratings_count
    self.endorsements = endorsements.to_enum(:each).map { |endorser| 
      records = Endorser.all(filter: "{Name} = \"#{endorser}\"") 
      if records.length == 0
        Endorser.create("Name" => endorser)
      else
        records[0]
      end
    }

    difference = Hashdiff.diff(before, self.serializable_fields)

    flagged = false
    author_ok = true

    $stderr.puts "\x1b[35m#{before["Title"]}\x1b[0m"
    difference.each do |(type, key, prev, new)|
      if key == "Author" && type == "~"
        unless authors.any? { |author| character_difference?(author.name, prev) }
          $stderr.puts "Author changed too much"
          flagged = true
          author_ok = false
        end
      end

      if key == "Title" && type == "~"
        unless new.downcase.start_with?(prev.downcase) || author_ok
          $stderr.puts "New title '#{new}' didn't start with old title '#{prev}'"
          flagged = true
        end
      end

      if type == "~"
        $stderr.puts "\x1b[34m#{type} #{key}: \x1b[31m#{prev} => \x1b[32m#{new}\x1b[0m"
      elsif type == "+"
        $stderr.puts "\x1b[34m#{type} #{key}: \x1b[32m#{prev}\x1b[0m"
      end
    end


    existing_book = prevent_duplicates_from.find { |other| other["ISBN"] == self["ISBN"] }
    if flagged
      Rollbar.warn("Skipping book", title: self["Title"])
    elsif existing_book
      if existing_book.endorsements.map{|e| e.id} != self.endorsements.map{|e| e.id}
        $stderr.puts "Updating #{self["Title"]} endorsers"
        existing_book.endorsements = self.endorsements
        existing_book.save
      else
        $stderr.puts "Skipping #{self["Title"]} due to duplicate"
      end
    else
      if self.new_record?
        self.create
      else
        self.save
      end
    end
  end

  private

  def goodreads_client
    self.class.goodreads_client
  end

  def self.goodreads_client
    @client ||= begin
       Goodreads::Client.new(api_key: ENV['GOODREADS_API_KEY'], api_secret: ENV['GOODREADS_SECRET'])
    end
  end

  def character_difference?(a, b, n = 4)
    (a.split('') - b.split('')).size <= n && (b.split('') - a.split('')).size <= n
  end
end