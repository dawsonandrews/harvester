require_relative './config/boot'
require "json"
require "date"
require "active_support/all"
require "base64"

set :root, File.dirname(__FILE__)

def last_3_months
  current = Date.today.beginning_of_month
  second = current - 1.month
  first = current - 2.months
  [first, second, current].map do |month|
    {
      name: month.strftime("%B %Y"),
      date_str: month.strftime("%Y%m%d")
    }
  end
end

get "/" do
  @last_3_months = last_3_months
  date = Date.parse(last_3_months[1][:date_str])
  date = Date.parse(params["date"]) if params["date"]
  start_date = date.beginning_of_month.strftime("%Y%m%d")
  end_date = date.end_of_month.strftime("%Y%m%d")


  info = api_request("/account/who_am_i").parse
  @company_name = info["company"]["name"]
  @date = date

  @users = api_request("/people").parse.inject({}) do |a, e|
    a[e["user"]["id"]] = ActiveSupport::HashWithIndifferentAccess.new(e["user"])
    a
  end

  projects = api_request("/projects")
               .parse
               .map { |proj| proj["project"] }

  @projects = projects.map do |project|
    total_hours = 0.0

    times = api_request("/projects/#{project['id']}/entries?from=#{start_date}&to=#{end_date}").parse
    next if times.empty?

    times = times.map do |day|
      total_hours += day["day_entry"]["hours"]
      ActiveSupport::HashWithIndifferentAccess.new(day["day_entry"])
    end

    ActiveSupport::HashWithIndifferentAccess.new(project.merge(total_hours: total_hours, times: times))
  end.compact

  erb :home
end

def api_request(path)
  base_url = "https://#{ENV['HARVEST_SUBDOMAIN']}.harvestapp.com"
  api_token = Base64.strict_encode64("#{ENV['HARVEST_EMAIL']}:#{ENV['HARVEST_PASSWORD']}")

  HTTP
    .auth("Basic #{api_token}")
    .headers(accept: "application/json")
    .get("#{base_url}#{path}")
end
