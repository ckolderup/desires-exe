require 'twitter'
require 'tempfile'
require 'RMagick'
require 'dotenv'
require 'ostruct'
include Magick

Dotenv.load

def random_text
  ["My desires are... Unconventional",
    "So show me",
    "Oh my god",
    "No way"].sample
end

def random_url
  'https://api.imgur.com/3/gallery/random/random/1'
end

def search_url(query)
  "https://api.imgur.com/3/gallery/search?q=#{query}"
end

def curl_cmd(client_id, url)
  "curl -s -H \"Authorization: Client-ID #{client_id}\" \"#{url}\""
end

def random_noun
  File.readlines('./nouns.txt').sample.chomp
end

def random_imgur_url
  noun = random_noun
  json = `#{curl_cmd(ENV['IMGUR_CLIENT_ID'], search_url(noun))}`
  response = JSON.parse(json, symbolize_names: true,
                              object_class: OpenStruct)
  sfw_urls = response.data.reject(&:nsfw)
                          .reject(&:animated)
                          .select(&:height)
                          .select { |i| i.height.fdiv(i.width) > 1.2 }
                          .map(&:link).first
end

def image(url)
  file = Tempfile.new('last_panel')
  file.write(`curl -s #{url}`)
  file.rewind
  bin = File.open(file,'r'){ |f| f.read }
  image = Image.from_blob(bin).first
  image.change_geometry!('500x') { |c,r,i| i.resize!(c,r) }


  template = Image.read("./template.png").first
  combined = (ImageList.new << template << image).append(true)

  file.write(combined.to_blob)
  file.rewind
  file
end

client = Twitter::REST::Client.new do |config|
  config.consumer_key       = ENV['TWITTER_CONSUMER_KEY']
  config.consumer_secret    = ENV['TWITTER_CONSUMER_SECRET']
  config.access_token        = ENV['TWITTER_OAUTH_TOKEN']
  config.access_token_secret = ENV['TWITTER_OAUTH_SECRET']
end

begin
  tries ||= 5
  client.update_with_media(random_text, image(random_imgur_url))
rescue Twitter::Error => e
  retry unless (tries -= 1).zero?
end
