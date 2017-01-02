require_relative './config/boot'
require "json"
require "date"
require "active_support/all"
require "base64"

class Time
  def floor(seconds = 60)
    Time.at((self.to_f / seconds).floor * seconds).utc
  end
end

set :root, File.dirname(__FILE__)

configure do
  $diskcache = Diskcached.new(File.join(settings.root, 'cache'))
  unless ENV["RACK_ENV"] == "development"
    $diskcache.flush # ensure caches are empty on startup
  end
end

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
  base_url = "https://#{ENV['HARVEST_SUBDOMAIN']}.harvestapp.com"
  http = HTTP.persistent(base_url)
  cache_ts = Time.now.floor(10.minutes).to_i

  @last_3_months = last_3_months
  date = Date.parse(last_3_months[1][:date_str])
  date = Date.parse(params["date"]) if params["date"]
  start_date = date.beginning_of_month.strftime("%Y%m%d")
  end_date = date.end_of_month.strftime("%Y%m%d")


  info = $diskcache.cache("company_info") { api_request("/account/who_am_i", http).parse }
  @company_name = info["company"]["name"]
  @date = date

  @users = $diskcache.cache("users") do
    api_request("/people", http).parse.inject({}) do |a, e|
      a[e["user"]["id"]] = ActiveSupport::HashWithIndifferentAccess.new(e["user"])
      a
    end
  end

  projects = $diskcache.cache("projects-#{cache_ts}") do
    api_request("/projects", http)
      .parse
      .map { |proj| proj["project"] }
  end

  @projects = projects.map do |project|
    total_hours = 0.0

    times = $diskcache.cache("project-#{project['id']}-#{start_date}-#{cache_ts}") do
      api_request("/projects/#{project['id']}/entries?from=#{start_date}&to=#{end_date}", http).parse
    end

    next if times.empty?

    times = times.map do |day|
      total_hours += day["day_entry"]["hours"]
      ActiveSupport::HashWithIndifferentAccess.new(day["day_entry"])
    end

    ActiveSupport::HashWithIndifferentAccess.new(project.merge(total_hours: total_hours, times: times))
  end.compact

  http.close

  erb :home
end

def api_request(path, http)
  api_token = Base64.strict_encode64("#{ENV['HARVEST_EMAIL']}:#{ENV['HARVEST_PASSWORD']}")

  http
    .auth("Basic #{api_token}")
    .headers(accept: "application/json")
    .get(path)
end
