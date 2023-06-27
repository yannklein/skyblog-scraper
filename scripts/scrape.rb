require 'erb'
require 'json'
require 'ostruct'
require 'date'
require "open-uri"
require "nokogiri"

def scrape(base_url)
  # create blog dir
  blog_dir = "#{URI(base_url).host}"
  Dir.mkdir blog_dir unless File.exists?(blog_dir)
  # parse the first page
  html_file = URI.open(base_url).read
  html_doc = Nokogiri::HTML.parse(html_file)
  # get the css 
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
  # get the amount of pages
  nb_pages = html_doc.search("ul.pagination li.last").search("a").attribute("href").value.match(/\/(\d*).html/)[1].to_i
  puts "#{nb_pages} pages to be scraped"
  for nb_page in (1..nb_pages)
    # parse and saved each article pages in a given page
    html_doc.search(".plink").each do |link|
      name_page = link.attribute("href").value.gsub("#{base_url}/", '').gsub(".html", '')
      copy_page(base_url, blog_dir, name_page)
    end
    # parse and saved each given page
    copy_page(base_url, blog_dir, nb_page)
  end
  # template = File.read(template_path)
  # data = OpenStruct.new(JSON.parse(File.read(data_path)))
  # # add the date to each day
  # sunday_added = 0
  # data['career_days'].each.with_index do |day, index|
  #   sunday_added += 1 if index != 0 && (index % 3).zero?
  #   day['date'] = Date.parse(data['start']) + index * 2 + sunday_added
  # end
  # # Demo day is always on Friday's
  # data['career_days'].last['date'] -= 1
  # generated = ERB.new(template).result(data.instance_eval { binding })
  # File.write(output_path, generated)
end

def copy_page(base_url, blog_dir, name_page)
  url = "#{base_url}/#{name_page}.html"
  # p url
  html_file = URI.open(url).read
  pic_base_urls = scrape_pictures(html_file, blog_dir)
  # remove every mention of the original website or skyrock
  html_file.gsub!("#{base_url}/", '/')
  pic_base_urls.each do |pic_base_url|
    html_file.gsub!("#{pic_base_url}/", "/")
  end
  File.write(File.join(__dir__,"../#{blog_dir}/index.html"), html_file) if name_page == 1
  File.write(File.join(__dir__,"../#{blog_dir}/#{name_page}.html"), html_file)
  puts "Page #{name_page} saved."
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