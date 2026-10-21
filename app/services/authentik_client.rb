require "json"
require "net/http"
require "uri"

class AuthentikClient
  class Error < StandardError; end

  REDIRECT_URI = "https://dedications.showway.biz/auth/callback"
  AUTHORIZATION_ENDPOINT = "https://auth.showway.biz/application/o/authorize/"
  TOKEN_ENDPOINT = "https://auth.showway.biz/application/o/token/"
  USERINFO_ENDPOINT = "https://auth.showway.biz/application/o/userinfo/"

  def self.configured?
    ENV["AUTHENTIK_CLIENT_ID"].present? && ENV["AUTHENTIK_CLIENT_SECRET"].present?
  end

  def self.authorization_url(state:)
    params = {
      client_id: client_id,
      redirect_uri: REDIRECT_URI,
      response_type: "code",
      scope: "openid profile email",
      state: state
    }

    "#{AUTHORIZATION_ENDPOINT}?#{URI.encode_www_form(params)}"
  end

  def self.exchange_code(code)
    response = post_form(
      TOKEN_ENDPOINT,
      grant_type: "authorization_code",
      code: code,
      redirect_uri: REDIRECT_URI
    )
    parse_response(response).fetch("access_token")
  rescue KeyError
    raise Error, "Authentikからアクセストークンを受け取れませんでした"
  end

  def self.userinfo(access_token)
    request = Net::HTTP::Get.new(URI(USERINFO_ENDPOINT))
    request["Authorization"] = "Bearer #{access_token}"

    parse_response(http_request(URI(USERINFO_ENDPOINT), request))
  end

  def self.client_id
    ENV.fetch("AUTHENTIK_CLIENT_ID")
  end

  def self.post_form(url, params)
    uri = URI(url)
    request = Net::HTTP::Post.new(uri)
    request.basic_auth(client_id, ENV.fetch("AUTHENTIK_CLIENT_SECRET"))
    request.set_form_data(params)

    http_request(uri, request)
  end
  private_class_method :post_form

  def self.http_request(uri, request)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(request)
    end
  rescue SocketError, Timeout::Error, Errno::ECONNREFUSED => error
    raise Error, "Authentikへ接続できませんでした: #{error.message}"
  end
  private_class_method :http_request

  def self.parse_response(response)
    body = JSON.parse(response.body)
    return body if response.is_a?(Net::HTTPSuccess)

    message = body["error_description"].presence || body["error"].presence || "不明なエラー"
    raise Error, "Authentikの認証に失敗しました: #{message}"
  rescue JSON::ParserError
    raise Error, "Authentikから正しい応答を受け取れませんでした"
  end
  private_class_method :parse_response
end
