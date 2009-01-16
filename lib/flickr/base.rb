module Flickr
  def self.new(*params)
    Flickr::Base.new(*params)
  end
  
  class Base
    attr_reader :api_key, :api_secret, :token_cache, :token
    
    REST_ENDPOINT = 'http://api.flickr.com/services/rest/'
    AUTH_ENDPOINT = 'http://flickr.com/services/auth/'
    UPLOAD_ENDPOINT = 'http://api.flickr.com/services/upload/'
    
    # create a new flickr object
    # 
    # You can either pass a hash with the following attributes:
    # 
    # * :key (Required)
    #     the API key
    # * :secret (Required)
    #     the API secret
    # * :token (Optional)
    #     Flickr::Auth::Token object
    #
    # or:
    # * config_file (Required)
    #     yaml file to load configuration from
    # * token_cache (Optional)
    #     location of the token cache file. This will override the setting in the config file
    # 
    # Config Example (yaml file)
    # ---
    # key: YOUR_API_KEY
    # secret: YOUR_API_SECRET
    # token_cache: token.yml
    # 
    def initialize(config_hash_or_file, token_cache = nil)
      if config_hash_or_file.is_a? Hash
        @api_key = config_hash_or_file[:key]
        @api_secret = config_hash_or_file[:secret]
        @token = config_hash_or_file[:token]
        raise 'config_hash must contain api key and secret' unless @api_key and @api_secret
      else 
        config = YAML.load_file(config_hash_or_file)
      
        @api_key = config['key']
        @api_secret = config['secret']
        @token_cache = token_cache || config['token_cache']
        raise 'flickr config file must contain an api key and secret' unless @api_key and @api_secret
      end
    end

    # sends a request to the flickr REST api
    # 
    # Params
    # * method (Required)
    #     name of the flickr method (ex. flickr.photos.search)
    # * options (Optional)
    #     hash of query parameters, you do not need to include api_key, api_sig or auth_token because these are added automatically
    # * http_method (Optional)
    #     choose between a GET and POST http request. Valid options are:
    #       :get (DEFAULT)
    #       :post
    # * endpoint (Optional)
    #     url of the api endpoint
    # 
    def send_request(method, options = {}, http_method = :get, endpoint = REST_ENDPOINT)
      options.merge!(:api_key => @api_key, :method => method)
      sign_request(options)
      
      rsp = request_over_http(options, http_method, endpoint)
      
      rsp = '<rsp stat="ok"></rsp>' if rsp == ""
      xm = XmlMagic.new(rsp)
      
      if xm[:stat] == 'ok'
        xm
      else
        raise Flickr::Errors.error_for(xm.err[:code].to_i, xm.err[:msg])
      end
    end
    
    # alters your api parameters to include a signiture and authorization token
    # 
    # Params
    # * options (Required)
    #     the hash of parameters to be passed to the send_request
    # * authorize (Optional)
    #     boolean value to determine if the call with include an auth_token (Defaults to true)
    # 
    def sign_request(options, authorize = true)
      options.merge!(:auth_token => self.auth.token(false).to_s, :api_key => @api_key) if authorize and self.auth.token(false)
      options.delete(:api_sig)
      options.merge!(:api_sig => Digest::MD5.hexdigest(@api_secret + options.to_a.sort_by{|k| k[0].to_s}.flatten.join)) if @api_secret
    end
    
    # creates and/or returns the Flickr::Test object
    def test() @test ||= Flickr::Test.new(self) end

    # creates and/or returns the Flickr::Photos object
    def photos() @photos ||= Flickr::Photos.new(self) end
      
    # creates and/or returns the Flickr::People object
    def people() @people ||= Flickr::People.new(self) end
      
    # creates and/or returns the Flickr::Auth object
    def auth() @auth ||= Flickr::Auth.new(self) end
      
    # creates and/or returns the Flickr::Uploader object
    def uploader() @uploader ||= Flickr::Uploader.new(self) end

    # creates and/or returns the Flickr::Contacts object
    def contacts() @contacts ||= Flickr::Contacts.new(self) end

    # creates and/or returns the Flickr::Urls object
    def urls() @urls ||= Flickr::Urls.new(self) end
            
    protected
    
    # For easier testing. You can mock this method with a XML file you're expecting to receive
    def request_over_http(options, http_method, endpoint)
      if http_method == :get
        api_call = endpoint + "?" + options.collect{|k,v| "#{k}=#{CGI.escape(v.to_s)}"}.join('&')
        Net::HTTP.get(URI.parse(api_call))
      else
        Net::HTTP.post_form(URI.parse(endpoint), options).body
      end
    end
    
  end
end