require "rubygems"
require "sinatra"
require "oauth"
require "oauth/consumer"
require "grackle"
require "httparty"
require "crack"
require "json"

enable :sessions

before do
  session[:oauth] ||= {}  
  
  consumer_key = ENV["consumer_key"]
  consumer_secret = ENV["consumer_secret"]

  @consumer ||= OAuth::Consumer.new(consumer_key, consumer_secret, :site => "http://twitter.com")
  
  if !session[:oauth][:request_token].nil? && !session[:oauth][:request_token_secret].nil?
    @request_token = OAuth::RequestToken.new(@consumer, session[:oauth][:request_token], session[:oauth][:request_token_secret])
  end
  
  if !session[:oauth][:access_token].nil? && !session[:oauth][:access_token_secret].nil?
    @access_token = OAuth::AccessToken.new(@consumer, session[:oauth][:access_token], session[:oauth][:access_token_secret])
  end
  
  if @access_token
    @client = Grackle::Client.new(:auth => {
      :type => :oauth,
      :consumer_key => consumer_key,
      :consumer_secret => consumer_secret,
      :token => @access_token.token, 
      :token_secret => @access_token.secret
    })    
  end
end

def get_current_track
  response = HTTParty.get('http://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&limit=5&user=tehviking&api_key=76ea6155040fc4be7d6b4051b2c5cf49')
  last_played = response["lfm"]["recenttracks"]["track"][0]
  if last_played["nowplaying"] == "true"
    last_played
  else
    return nil  
  end
end

get "/" do
  @current_track = get_current_track
  if @access_token
    @statuses = @client.statuses.friends_timeline? :count => 10
    erb :index
  else
    '<a href="/request">Sign On</a>'
  end
end

get "/thanks" do
  erb :thanks
  @client.statuses.update! :status=>"I'm loving #{@current_track["name"]} by #{@current_track["artist"]} right now. (via http://bit.ly/dj8fAY)"  
end

get "/request" do
  @request_token = @consumer.get_request_token(:oauth_callback => "http://#{request.host}/auth")
  session[:oauth][:request_token] = @request_token.token
  session[:oauth][:request_token_secret] = @request_token.secret
  redirect @request_token.authorize_url
end

get "/auth" do
  @access_token = @request_token.get_access_token :oauth_verifier => params[:oauth_verifier]
  session[:oauth][:access_token] = @access_token.token
  session[:oauth][:access_token_secret] = @access_token.secret
  redirect "/"
end

get "/logout" do
  session[:oauth] = {}
  redirect "/"
end
