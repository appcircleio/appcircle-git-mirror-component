require 'colored'
require 'uri'

MINIMUM_GIT = Gem::Version.new('2.31')

def get_env_variable(key)
  ENV[key].nil? || ENV[key] == '' ? nil : ENV[key]
end

def abort_with1(message)
  puts "@@[error] #{message}".red
  exit 1
end

def get_info_msg(message)
  puts " \n#{message.green}"
end

def http_url(key, value)
  abort_with1("#{key} must be an http or https URL.") unless value.match?(%r{\Ahttps?://[^/\s]+/?\S*\z})
  abort_with1("#{key} must not contain a user or password.") if URI(value).userinfo
  value.end_with?('/') ? value : "#{value}/"
end

# The URL forms git and the dependency managers use for the source: https, http, ssh and the scp-like
# git@host:path. All of them go to the mirror over https.
def source_forms(source)
  uri = URI(source)
  path = uri.path.delete_prefix('/')
  host = uri.port == uri.default_port ? uri.host : "#{uri.host}:#{uri.port}"
  ["https://#{host}/#{path}", "http://#{host}/#{path}", "ssh://git@#{uri.host}/#{path}", "git@#{uri.host}:#{path}"].uniq
end

def git_version
  output = `git --version 2>/dev/null`
  abort_with1('git is not installed on the runner.') unless $?.success?
  Gem::Version.new(output[/\d+\.\d+(\.\d+)?/])
end

mirror = get_env_variable('AC_MIRROR_GIT')
if mirror.nil?
  puts 'AC_MIRROR_GIT is empty: git uses the URLs of the project and its dependencies.'
  exit 0
end
mirror = http_url('AC_MIRROR_GIT', mirror)
source = http_url('AC_MIRROR_GIT_SOURCE', get_env_variable('AC_MIRROR_GIT_SOURCE') || 'https://github.com/')

env_file = get_env_variable('AC_ENV_FILE_PATH')
abort_with1('AC_ENV_FILE_PATH is not set.') if env_file.nil?

version = git_version
if version < MINIMUM_GIT
  abort_with1("git #{version} is too old: the Git Mirror step needs git #{MINIMUM_GIT} or later (GIT_CONFIG_COUNT).")
end

# Git configuration for the later steps of this build only, through GIT_CONFIG_COUNT / GIT_CONFIG_KEY_<n> /
# GIT_CONFIG_VALUE_<n>: nothing is written to ~/.gitconfig or the repository. Entries already in the
# environment (another Git Mirror step, for another source) are kept.
# No credentials: git authenticates to the mirror like to any other repository on that server, for example with
# the credentials Git Clone caches for the app's server.
first = (get_env_variable('GIT_CONFIG_COUNT') || '0').to_i
forms = source_forms(source)
lines = []
forms.each_with_index do |form, i|
  lines << "GIT_CONFIG_KEY_#{first + i}=url.#{mirror}.insteadOf"
  lines << "GIT_CONFIG_VALUE_#{first + i}=#{form}"
end
lines << "GIT_CONFIG_COUNT=#{first + forms.size}"
File.open(env_file, 'a') { |f| lines.each { |line| f.puts(line) } }

forms.each { |form| puts "Git Mirror: #{form} -> #{mirror}" }
puts "Git Mirror: git #{version}"
get_info_msg('Git Mirror is configured for the next steps.')
