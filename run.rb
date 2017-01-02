require "http"
require "json"
require "date"
require "active_support/all"
require "dotenv"
require "base64"

Dotenv.load

def api_request(path)
  base_url = "https://#{ENV['HARVEST_SUBDOMAIN']}.harvestapp.com"
  api_token = Base64.strict_encode64("#{ENV['HARVEST_EMAIL']}:#{ENV['HARVEST_PASSWORD']}")

  HTTP
    .auth("Basic #{api_token}")
    .headers(accept: "application/json")
    .get("#{base_url}#{path}")
end

date = Date.today
date = date - 1.month
start_date = date.beginning_of_month.strftime("%Y%m%d")
end_date = date.end_of_month.strftime("%Y%m%d")

info = api_request("/account/who_am_i").parse

puts company_name = info["company"]["name"]

users = api_request("/people").parse.inject({}) do |a, e|
  a[e["user"]["id"]] = ActiveSupport::HashWithIndifferentAccess.new(e["user"])
  a
end

projects = api_request("/projects")
             .parse
             .map { |proj| proj["project"] }

projects = projects.map do |project|
  total_hours = 0.0

  times = api_request("/projects/#{project['id']}/entries?from=#{start_date}&to=#{end_date}").parse
  next if times.empty?

  times = times.map do |day|
    total_hours += day["day_entry"]["hours"]
    ActiveSupport::HashWithIndifferentAccess.new(day["day_entry"])
  end

  ActiveSupport::HashWithIndifferentAccess.new(project.merge(total_hours: total_hours, times: times))
end.compact

# OUTPUT
projects.each do |project|
  puts "#{project[:name]} - #{project[:total_hours]}h"
  project[:times].each do |time|
    user = users[time[:user_id]]
    name = "#{user[:first_name]} #{user[:last_name]}"
    puts "  - #{time[:hours]}h - #{name} - #{time[:notes]}"
  end
  puts "\n\n"
end