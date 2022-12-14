#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'net/http'
require 'uri'
require 'yaml'
# Fetch API files
module API
  def self.fetch(uri)
    url = URI(uri)
    https = Net::HTTP.new(url.host, url.port)
    https.use_ssl = true
    request = Net::HTTP::Get.new(url)
    response = https.request(request)
    return JSON.parse(response.body) unless response.code.eql? 200
  end
end

categories = JSON.parse(File.read('./data/categories.json'))
regions = API.fetch('https://2fa.directory/api/v3/regions.json')
entries = API.fetch('https://2fa.directory/api/v3/all.json')
used_regions = []

regions.each do |id, region|
  next unless region['count'] >= 10 && !id.eql?('int')

  used_regions.push(id)
  dir = "content/#{id}"
  FileUtils.mkdir_p dir
  File.open("#{dir}/_index.md", 'w') do |file|
    file.write("---\nlayout: tables\nregion:\n  id: \"#{id}\"\n  name: \"#{region['name']}\"\n---")
  end

  used_categories = {}
  entries.each do |_, entry|
    entry_regions = entry['regions']
    unless entry_regions.nil?
      included = entry_regions.reject { |r| r.start_with?('-') }
      excluded = entry_regions.select { |r| r.start_with?('-') }.map! { |v| v.tr('-', '') }
      next unless included&.include?(id) && !excluded.include?(id)
    end

    entry['keywords'].each { |category| used_categories.merge!(categories.slice(category)) }
  end
  File.open("./data/#{id}.json", 'w') { |file| file.write JSON.generate used_categories.sort.to_h }
end

all_regions = {}
regions_uri = 'https://raw.githubusercontent.com/stefangabos/world_countries/master/data/countries/en/world.json'
API.fetch(regions_uri).select do |region|
  all_regions[region['alpha2']] = region['name'] if used_regions.include? region['alpha2']
end
# Change long official names
all_regions.merge!({ 'us' => 'United States', 'gb' => 'United Kingdom', 'tw' => 'Taiwan', 'ru' => 'Russia',
                     'kr' => 'South Korea' })

# Change output format to array of hashmaps
output = all_regions.map { |k, v| { 'id' => k, 'name' => v } }
File.open('data/regions.yml', 'w') { |file| file.write output.to_yaml }
