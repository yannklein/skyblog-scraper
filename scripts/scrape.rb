require 'erb'
require 'json'
require 'ostruct'
require 'date'
require "open-uri"
require "nokogiri"
require "cgi"

def scrape(base_url)
  # create blog dir
  blog_dir = "#{URI(base_url).host}"
  Dir.mkdir blog_dir unless File.exists?(blog_dir)
  # parse the first page
  html_file = URI.open(base_url).read
  html_doc = Nokogiri::HTML.parse(html_file)
  # get the css
  scrape_css(html_doc, blog_dir)
  # get the amount of pages
  nb_pages = html_doc.search("ul.pagination li.last").search("a").attribute("href").value.match(/\/(\d*).html/)[1].to_i
  puts "#{nb_pages} pages to be scraped"
  # iterate over each page
  for nb_page in (1..nb_pages)
    # parse the nth page
    html_file = URI.open("#{base_url}/#{nb_page}.html").read
    html_doc = Nokogiri::HTML.parse(html_file)
    # parse and saved each articles
    html_doc.search(".plink").each do |link|
      name_page = link.attribute("href").value.gsub("#{base_url}/", '').gsub(".html", '')
      copy_page(base_url, blog_dir, name_page)
    end
    # parse and saved each photo details
    # Example: https://soph-yan.skyrock.com/photo.html?id_article=514182126&id_article_media=-1
    html_doc.search(".image-container a").each do |link|
      uri = URI(link.attribute("href").value)
      article_id = CGI::parse(uri.query)["id_article"][0]
      new_url = "#{article_id}-#{uri.path[1..]}"
      copy_detail_page(link.attribute("href").value, blog_dir, new_url, base_url)
      link.attribute("href").value = new_url
    end
    # parse and saved each given page
    copy_page(base_url, blog_dir, nb_page, html_doc.to_html)
  end
end

def scrape_css(html_doc, blog_dir)
  html_doc.search('head > link[rel="stylesheet"]').each do |css_link|
    url = css_link.attribute("href").value
    css_file = URI.open(url).read
    filename = File.join(__dir__,"../#{blog_dir}/#{URI(url).path}")
    dirname = File.dirname(filename)
    unless File.directory?(dirname)
      FileUtils.mkdir_p(dirname)
    end
    open(filename, 'wb') do |file|
      file << css_file
    end
    puts "Saved css file: #{url}"
  end
end

def copy_page(base_url, blog_dir, name_page, html_file = nil)
  url = "#{base_url}/#{name_page}.html"
  # p url
  html_file = URI.open(url).read if html_file.nil?
  pic_base_urls = scrape_pictures(html_file, blog_dir)
  # remove every mention of the original website or skyrock
  html_file.gsub!("#{base_url}/", '').gsub!('href="/', 'href="')
  pic_base_urls.each do |pic_base_url|
    html_file.gsub!("#{pic_base_url}/", "")
  end
  File.write(File.join(__dir__,"../#{blog_dir}/index.html"), html_file) if name_page == 1
  File.write(File.join(__dir__,"../#{blog_dir}/#{name_page}.html"), html_file)
  puts "Page #{name_page} saved."
end

def copy_detail_page(original_url, blog_dir, new_url, base_url)
  url = original_url
  # p url
  html_file = URI.open(url).read
  pic_base_urls = scrape_pictures(html_file, blog_dir)
  # remove every mention of the original website or skyrock
  html_file.gsub!("#{base_url}/", '').gsub!('href="/', 'href="')
  pic_base_urls.each do |pic_base_url|
    html_file.gsub!("#{pic_base_url}/", "")
  end
  File.write(File.join(__dir__,"../#{blog_dir}/#{new_url}"), html_file)
  puts "Page #{new_url} saved."
end

def scrape_pictures(html_file, blog_dir)
  pic_base_url = []
  html_doc = Nokogiri::HTML.parse(html_file)
  nb_pages = html_doc.search("img").each do |img|
    img_url = img.attribute("src").value
    img_name = URI(img_url).path
    next unless img_name.match(/(jpg|png|jpeg|bmp|svg)/)
    pic_base_url << "#{URI(img_url).scheme}://#{URI(img_url).host}"
    begin
      image = URI.open(img_url).read
    rescue OpenURI::HTTPError
      puts "#{img_url} is broken"
    else
      filename = File.join(__dir__,"../#{blog_dir}/#{img_name}")
      dirname = File.dirname(filename)
      unless File.directory?(dirname)
        FileUtils.mkdir_p(dirname)
      end
      open(filename, 'wb') do |file|
        file << image
      end
      puts "Saved image: #{img_url}"
    end
  end
  pic_base_url
end