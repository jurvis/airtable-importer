require_relative '../pinboard_importer'

describe PinboardImporter do
  before(:each) do
    @importer = PinboardImporter.new
  end

  context "Get ISBN From Bookmarked Links" do
    
    it "should return correct isbn for Goodreads Link" do
      link = "https://www.goodreads.com/book/show/765172.Cane?from_search=true&from_srp=true&qid=kMwbB2wxy1&rank=3"

      isbn = @importer.get_isbn_from_goodreads(link)

      expect(isbn).to eq '9780871401519'
    end

    it "should return correct isbn for Amazon link" do
      link = "https://www.amazon.com/Liberty-Utilitarianism-Essays-Oxford-Classics/dp/0199670803/"
      
      isbn = @importer.get_isbn_from_amazon(link)
      
      expect(isbn).to eq '0199670803'
    end
  end
end