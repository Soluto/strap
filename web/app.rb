require "sinatra"
require "omniauth-github"
require "octokit"
require "securerandom"
require "awesome_print" if ENV["RACK_ENV"] == "development"

GITHUB_KEY = ENV["GITHUB_KEY"]
GITHUB_SECRET = ENV["GITHUB_SECRET"]
SESSION_SECRET = ENV["SESSION_SECRET"] || SecureRandom.hex
STRAP_ISSUES_URL = ENV["STRAP_ISSUES_URL"] || \
                   "https://github.com/mikemcquaid/strap/issues/new"
STRAP_BEFORE_INSTALL = ENV["STRAP_BEFORE_INSTALL"]

set :sessions, secret: SESSION_SECRET

use OmniAuth::Builder do
  options = { scope: "user:email,repo" }
  options[:provider_ignores_state] = true if ENV["RACK_ENV"] == "development"
  provider :github, GITHUB_KEY, GITHUB_SECRET, options
end

get "/auth/github/callback" do
  session[:auth] = request.env["omniauth.auth"]
  return_to = session.delete :return_to
  return_to = "/" if !return_to || return_to.empty?
  redirect to return_to
end

get "/" do
  if request.scheme == "http" && ENV["RACK_ENV"] != "development"
    redirect to "https://#{request.host}#{request.fullpath}"
  end

  before_install_list_item = nil
  if STRAP_BEFORE_INSTALL
    before_install_list_item = "<li>#{STRAP_BEFORE_INSTALL}</li>"
  end

  @title = "Strap"
  @text = <<-EOS
Strap is a script to bootstrap a minimal macOS development system. This does not assume you're doing Ruby/Rails/web development but installs the minimal set of software every macOS developer will want.</br>
Strap uses dotfiles to configure the system, you can read more about dotfiles <a href="https://askubuntu.com/questions/94780/what-are-dot-files">here</a>
</br></br>
<h3>Before you run the strap.sh script:</h3>
<ol>
	<li>Make sure you have a Github account.</li>
  <li>If you don't already have a dotfiles repository, fork your own from this <a href="https://github.com/oryagel/dotfiles">existing repository.</a> You can use the dotfiles to customize the apps that strap script will install.</li>
	<li>Make sure you have an Apple account (Apple Id) for the Mac App store.</li>
</ol>
</br>
<h3>What this script does:</h3>
<ol>
   <li>Install XCode cli tools, Homebrew and some basic dependencies</li>
   <li>Check and install software updates</li>
   <li>Clone the dotfiles repository from your Github profile to your home directory. You can start by forking an <a href="https://github.com/oryagel/dotfiles">existing repository</a> to your Github account</li>
   <li>Install the brews from your customized Brewfile which should be in your dotfiles repository</li>
   <li>Install Android SDK and dependencies from your customized androidsdk file which should be in your dotfiles repository</li>
</ol>
</br>
<h3>To Strap your system:</h3>
<ol>
  #{before_install_list_item}
  <li><a href="/strap.sh">Download the <code>strap.sh</code></a> that's been customised for your GitHub user (or <a href="/strap.sh?text=1">view it</a> first). This will prompt for access to your email, public and private repositories.</li>
  <li>Run Strap in Terminal.app with <code>bash ~/Downloads/strap.sh</code>.</li>
  <li>If something failed, run Strap with more debugging output in Terminal.app with <code>bash ~/Downloads/strap.sh --debug</code> and file an issue at <a href="#{STRAP_ISSUES_URL}">#{STRAP_ISSUES_URL}</a></li>
  <li>Delete the customised <code>strap.sh</code></a> (it has a GitHub token in it) in Terminal.app with <code>rm -f ~/Downloads/strap.sh</code></a></li>
</ol>



<a href="https://github.com/mikemcquaid/strap"><img style="position: absolute; top: 0; right: 0; border: 0; width: 149px; height: 149px;" src="//aral.github.com/fork-me-on-github-retina-ribbons/right-graphite@2x.png" alt="Fork me on GitHub"></a>
EOS
  erb :root
end

get "/strap.sh" do
  auth = session[:auth]

  if !auth && GITHUB_KEY && GITHUB_SECRET
    query = request.query_string
    query = "?#{query}" if query && !query.empty?
    session[:return_to] = "#{request.path}#{query}"
    redirect to "/auth/github"
  end

  content = IO.read(File.expand_path("#{File.dirname(__FILE__)}/../bin/strap.sh"))
  content.gsub!(/^STRAP_ISSUES_URL=.*$/, "STRAP_ISSUES_URL='#{STRAP_ISSUES_URL}'")

  content_type = params["text"] ? "text/plain" : "application/octet-stream"

  if auth
    content.gsub!(/^# STRAP_GIT_NAME=$/, "STRAP_GIT_NAME='#{auth["info"]["name"]}'")
    content.gsub!(/^# STRAP_GIT_EMAIL=$/, "STRAP_GIT_EMAIL='#{auth["info"]["email"]}'")
    content.gsub!(/^# STRAP_GITHUB_USER=$/, "STRAP_GITHUB_USER='#{auth["info"]["nickname"]}'")
    content.gsub!(/^# STRAP_GITHUB_TOKEN=$/, "STRAP_GITHUB_TOKEN='#{auth["credentials"]["token"]}'")
  end

  erb content, content_type: content_type
end
