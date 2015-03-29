require 'open-uri'
require 'uri'
require 'json'
require 'nokogiri'
require 'awesome_print'

SERVICE_URI = URI('http://127.0.0.1:8000/receive_bills')

urls = %w(
http://www.mcsi.ro/Transparenta-decizionala/Proiecte-2010
http://www.mcsi.ro/Transparenta-decizionala/Proiecte-2011
http://www.mcsi.ro/Transparenta-decizionala/Proiecte-2012-(1)
http://www.mcsi.ro/Transparenta-decizionala/Proiecte-2013
http://www.mcsi.ro/Transparenta-decizionala/Proiecte-2014
http://www.mcsi.ro/Transparenta-decizionala/Proiecte-2015
)

def extract_links(url)
  docs = []
  open(url) do |f|
    html = f.read
    doc = Nokogiri::HTML(html)
    node = doc.css("#center-col .ct").first
    node.children.each do |x|
      next if x.attribute('class').nil?

      x.unlink if /CMS/ =~ x.attribute('class').value
      x.unlink if /document-title/ =~ x.attribute('class').value
    end

    node.inner_html.split(/\p{Z}*^(?!20).+[^0-9]\d+\.\p{Z}+/).each_with_index do |item, index|
      # puts "======[ #{ index } ]====="
      # puts item.strip

      node = Nokogiri::HTML(item)
      links = node.css('a')
      next if links.empty?

      node.css('a').map(&:unlink)

      title = node.text.gsub(/(\s|\p{Z}|-)+/, ' ').strip

      content = []
      links.each do |l|
        next if l.attribute('href').to_s.start_with?("mailto:")

        content << {
          :name => l.text.strip,
          :value => URI.join(url, l.attribute('href').value).to_s,
          :type => 'uri'
        }
      end

      docs << {
        :url => url,
        :title => title,
        :content => content
      }

      # puts "#{index}. #{node.text.gsub(/(\s|\p{Z})+/, ' ')} - #{links.length} links"
    end
  end

  docs
end

# url = "http://www.mcsi.ro/Transparenta-decizionala/Proiecte-2011"
docs = urls.map { |url| extract_links(url) }.flatten

=begin
puts JSON.dump(docs)
=end
ap docs

Net::HTTP.start(SERVICE_URI.host, SERVICE_URI.port) do |http|
  response = http.post(SERVICE_URI.path, JSON.dump(docs))
  p response
  p response.body
end
