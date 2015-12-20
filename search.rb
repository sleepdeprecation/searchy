require 'set'

require_relative 'database.rb'
require_relative 'utils.rb'

class Result < Struct.new(:url, :score, :title)
end

def search(search_term)
	terms = search_term.split
	terms.delete_if do |k|
		k.tokenize!
		k == ""
	end

	scores = []
	Page.all.each do |page|
		score = 0
		terms.each do |term|
			unless page.has_word(term)
				next
			end

			term_freq = page.get_word_in_page(term).count
			inverse_doc_freq = Word.where(:word => term).first.inverse_document_frequency

			score += term_freq * inverse_doc_freq
		end

		scores << Result.new(page.url, score, (page.title != "" ? page.title : page.url))
	end


	scores.sort_by! { |s| [-s.score, s.url, s.title] }

	scores.tap { |sc| sc.delete_if {|s| s.score == 0 } }
end



def crawl_ten(page_url)
	page = crawl_page(page_url)

	pages_to_crawl = []

	PageLinks.where(:prime_id => page.id).each do |pl|
		unless page.crawled?
			pages_to_crawl << Page[pl.linked_id]
			pages_to_crawl.uniq!

			if pages_to_crawl.length > 10
				break
			end
		end
	end


	(1..10).each do |i|
		crawl_page(pages_to_crawl[i])

		if pages_to_crawl.length <= 10
			PageLinks.where(:prime_id => page.id).each do |pl|
				unless page.crawled?
					pages_to_crawl << Page[pl.linked_id]
					pages_to_crawl.uniq!

					if pages_to_crawl.length > 10
						break
					end
				end
			end
		end
	end
end

def crawl_page(page_url)
	puts "crawling #{page_url}"
	page = Page.find_or_create(:url => page_url)

	unless page.crawled?
		page.crawl
	end

	page
end
