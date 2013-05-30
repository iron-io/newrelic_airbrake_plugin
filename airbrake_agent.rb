require 'yaml'
require 'active_resource'
require 'iron_cache'
# https://github.com/newrelic-platform/iron_sdk
require 'newrelic_platform'

# Un-comment to test/debug locally
# def config; @config ||= YAML.load_file('./airbrake_agent.config.yml'); end

# Setup
# Configure NewRelic client
@new_relic = NewRelic::Client.new(:license => config['newrelic']['license'],
                                  :guid => config['newrelic']['guid'],
                                  :version => config['newrelic']['version'])

# Configure IronCache
@cache = IronCache::Client.new(config['iron']).cache('newrelic-parse-agent')

# Airbrake setup
AB_SITE = "http://#{config['airbrake']['account']}.airbrake.io"
AB_TOKEN = config['airbrake']['token']

class Airbrake < ActiveResource::Base
  self.site = AB_SITE

  class << self
    @@auth_token = AB_TOKEN

    def find(*arguments)
      arguments = append_auth_token_to_params(*arguments)
      super(*arguments)
    end

    def append_auth_token_to_params(*arguments)
      opts = arguments.last.is_a?(Hash) ? arguments.pop : {}
      opts = opts.has_key?(:params) ? opts : opts.merge(:params => {})
      opts[:params] = opts[:params].merge(:auth_token => @@auth_token)
      arguments << opts
      arguments
    end
  end
end

class Error < Airbrake; end

class Project < Airbrake; end


# Helpers
def duration(from, to)
  dur = from ? (to - from).to_i : 3600

  dur > 3600 ? 3600 : dur
end

def up_to(to = nil)
  if to
    @up_to = Time.at(to.to_i).utc
  else
    @up_to ||= Time.now.utc
  end
end

def processed_at(processed = nil)
  if processed
    @cache.put('previously_processed_at', processed.to_i)

    @processed_at = Time.at(processed.to_i).utc
  elsif @processed_at.nil?
    item = @cache.get 'previously_processed_at'
    min_prev_allowed = (up_to - 3600).to_i

    at = if item && item.value.to_i > min_prev_allowed
           item.value
         else
           min_prev_allowed
         end

    @processed_at = Time.at(at).utc
  else
    @processed_at
  end
end

def all_errors
  return @all_errors if defined? @all_errors

  @all_errors = []
  page = 0
  begin
    errs = Error.find(:all,
                      :params => {
                        :page => page,
                        :show_resolved => true
                      })
    @all_errors |= errs.to_a
    page += 1
  end while errs.count >= 30

  @all_errors
end

def all_projects
  return @all_projects if defined? @all_projects

  @all_projects = []
  page = 0
  begin
    projs = Project.find :all, :params => {:page => page}
    @all_projects |= projs.to_a
    page += 1
  end while projs.count >= 30

  @all_projects
end

def with_each_project(errors)
  all_projects.each do |project|
    proj_errs = errors.select { |e| e.project_id == project.id }

    yield project.name, proj_errs
  end
end

def by_envs(errors)
  @envs ||= {
    'Production' => ['production', 'prod'],
    'Staging' => ['staging', 'stage'],
    'Development' => ['dev', 'development']
  }

  @envs.each_with_object({}) do |(name, envs), result|
    env_errs = errors.select { |e| envs.include?(e.rails_env) }

    result[name] = {
      'total' => env_errs.count,
      'resolved' => env_errs.select { |e| e.resolved == true }.count,
      'open' => env_errs.select { |e| e.resolved == false }.count
    }
  end
end

def process_and_send_results
  collector = @new_relic.new_collector
  results = {}

  up_to # set processing timestamp
  yield results

  component_name = "Airbrake (#{config['airbrake']['account'].capitalize})"
  component = collector.component(component_name)
  results.each do |project, stats|
    stats.each do |env, stat|
      stat.each do |kind, value|
        metric_name = "#{env}/#{kind.capitalize}/#{project}"

        component.add_metric metric_name, 'errors', value
      end
    end
  end
  component.options[:duration] = duration(processed_at, up_to)

  # Submit data to New Relic
  collector.submit

  # update processed_at timestamp in cache
  processed_at(up_to)
end


# Process

process_and_send_results do |results|
  # Total stats
  results['All Projects'] = by_envs(all_errors)

  # Per project stats
  with_each_project(all_errors) do |prj_name, errs|
    results[prj_name] = by_envs(errs)
  end
end
