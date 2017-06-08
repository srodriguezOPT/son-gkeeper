# -*- coding: utf-8 -*-
##
## Copyright (c) 2015 SONATA-NFV
## ALL RIGHTS RESERVED.
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
##
## Neither the name of the SONATA-NFV
## nor the names of its contributors may be used to endorse or promote
## products derived from this software without specific prior written
## permission.
##
## This work has been performed in the framework of the SONATA project,
## funded by the European Commission under Grant number 671517 through
## the Horizon 2020 and 5G-PPP programmes. The authors would like to
## acknowledge the contributions of their colleagues of the SONATA
## partner consortium (www.sonata-nfv.eu).

require 'json'
require 'sinatra'
require 'yaml'
require 'net/http'
require 'base64'
require 'jwt'
require 'resolv'
require 'uri'
require_relative 'helpers'


#def parse_json(message)
  # Check JSON message format
#  begin
#    parsed_message = JSON.parse(message)
#  rescue JSON::ParserError => e
    # If JSON not valid, return with errors
#    return message, e.to_s + "\n"
#  end
#  return parsed_message, nil
#end

class Keycloak < Sinatra::Application
  # logger.info "Adapter: Starting configuration"
  # Load configurations
  # keycloak_config = YAML.load_file 'config/keycloak.yml'

  # Load authorization mappings
  @@auth_mappings = YAML.load_file 'config/mappings.yml'

  @@port = ENV['KEYCLOAK_PORT']
  @@uri = ENV['KEYCLOAK_PATH']
  @@realm_name = ENV['SONATA_REALM']
  @@client_name = ENV['CLIENT_NAME']

  ## Get the ip of keycloak. Only works for docker-compose
  #@@address = Resolv::DNS.new.getaddress("son-keycloak")
  @@address = ENV['KEYCLOAK_ADDRESS']

  # TODO: Add admin custom credentials
  # @@admin_name = ENV['ADMIN_NAME']
  # @@admin_password = ENV['ADMIN_PASSWORD']

  # TODO: remove this or comment enable/disable local testing
  #@@address = 'localhost'
  #@@client_secret = 'df7e816d-0337-4fbe-a3f4-7b5263eaba9f'
  #@@access_token = Keycloak.get_adapter_token
  ## TODO: remove this or comment enable/disable local testing
  #@@port = 8081
  #@@uri = 'auth'
  #@@realm_name = 'master'
  #@@client_name = 'adapter'

  begin
    keycloak_yml = YAML.load_file('config/keycloak.yml')
    keycloak_yml['address'] = @@address
    keycloak_yml['port'] = @@port
    keycloak_yml['uri'] = @@uri
    keycloak_yml['realm'] = @@realm_name
    keycloak_yml['client'] = @@client_name
    File.open('config/keycloak.yml', 'w') do |f|
      f.puts keycloak_yml.to_yaml
    end
  rescue
    puts "Error updating config file"
  end

  def Keycloak.get_adapter_token
    begin
      url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/realms/#{@@realm_name}/protocol/openid-connect/token")
      res = Net::HTTP.post_form(url, 'client_id' => @@client_name, 'client_secret' => @@client_secret,
                                'username' => "admin",
                                'password' => "admin",
                                'grant_type' => "client_credentials")

      parsed_res, errors = parse_json(res.body)

      if parsed_res['access_token']
        # puts "ACCESS_TOKEN RECEIVED", parsed_res['access_token']
        File.open('config/token.json', 'w') do |f|
          f.puts parsed_res['access_token']
        end
        return parsed_res['access_token']
      else
        return res.code.to_i
      end
    rescue
      return 503
    end
  end

  def get_oidc_endpoints
    # Call http://localhost:8081/auth/realms/master/.well-known/openid-configuration to obtain endpoints
    url = URI.parse("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/realms/#{@@realm_name}/.well-known/openid-configuration")

    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Get.new(url.to_s)

    response = http.request(request)
    # puts response.read_body # <-- save endpoints file
    File.open('config/endpoints.json', 'w') do |f|
      f.puts response.read_body
    end
  end

  def get_adapter_install_json
    # Get client (Adapter) registration configuration
    # 'http://localhost:8081/auth/realms/master/clients-registrations/openid-connect'
    # Avoid using hardcoded authorization - > # http://localhost:8081/auth/realms/master/?

    #url = URI("http://127.0.0.1:8081/auth/realms/master/clients-registrations/install/adapter")
    url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/realms/#{@@realm_name}/clients-registrations/install/adapter")
    # p "URL", "http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/realms/#{@@realm_name}/clients-registrations/install/adapter"
    http = Net::HTTP.new(url.host, url.port)

    request = Net::HTTP::Get.new(url.to_s)
    request.basic_auth(@@client_name.to_s, @@client_secret.to_s)
    request["content-type"] = 'application/json'

    response = http.request(request)
    # p "RESPONSE", response.code
    # p "RESPONSE.read_body222", response.read_body
    # puts response.read_body # <-- save endpoints file
    File.open('config/keycloak.json', 'w') do |f|
      f.puts response.read_body
    end
  end

  def get_adapter_token
    url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/realms/#{@@realm_name}/protocol/openid-connect/token")
    # http = Net::HTTP.new(url.host, url.port)

    # request = Net::HTTP::Post.new(url.to_s)
    # request.basic_auth(@client_name.to_s, @client_secret.to_s)
    # request["content-type"] = 'application/json'
    # body = {"username" => "admin",
    #        "credentials" => [
    #            {"type" => "client_credentials",
    #             "value" => "admin"}]}
    # request.body = body.to_json

    res = Net::HTTP.post_form(url, 'client_id' => @@client_name, 'client_secret' => @@client_secret,
                              #'username' => "admin",
                              #'password' => "admin",
                              'grant_type' => "client_credentials")

    # res = http.request(request)

    # p "RESPONSE", res
    # p "RESPONSE.read_body333", res.read_body

    parsed_res, code = parse_json(res.body)

    if parsed_res['access_token']
      # puts "ACCESS_TOKEN RECEIVED", parsed_res['access_token']

      File.open('config/token.json', 'w') do |f|
        f.puts parsed_res['access_token']
      end
      # @access_token = parsed_res['access_token']
      parsed_res['access_token']
    end
  end

  def self.get_realm_public_key
    url = URI.parse("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/realms/#{@@realm_name}")

    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Get.new(url.to_s)

    begin
      response = http.request(request)
      parsed_response, code = parse_json(response.body)
      # puts response.read_body # <-- save endpoints file
      File.open('config/keycloak.yml', 'a') do |f|
        f.puts "\n"
        f.puts "realm_public_key: #{parsed_response['public_key']}"
      end
    rescue Errno::ECONNREFUSED
      # logger.info 'Retrieving Keycloak Public Key failed!'
    end
  end

  def decode_token(token, keycloak_pub_key)
    logger.info 'Decoding received Access Token'
    begin
      decoded_payload, decoded_header = JWT.decode token, keycloak_pub_key, true, { :algorithm => 'RS256' }
      # puts "DECODED_HEADER: ", decoded_header
      # puts "DECODED_PAYLOAD: ", decoded_payload
      return decoded_payload, decoded_header
    # Handle expired token, e.g. logout user or deny access
    rescue JWT::DecodeError
      logger.debug 'Error 401: A token must be passed'
      json_error(401, 'A token must be passed')
    rescue JWT::ExpiredSignature
      logger.debug 'Error 403: The token has expired'
      json_error(403, 'The token has expired')
    rescue JWT::InvalidIssuerError
      logger.debug 'Error 403: The token does not have a valid issuer'
      json_error(403, 'The token does not have a valid issuer')
    rescue JWT::InvalidIatError
      logger.debug 'Error 403: The token does not have a valid "issued at" time'
      json_error(403, 'The token does not have a valid "issued at" time')
    end
  end

  def get_public_key
    logger.info 'Building PEM Keycloak Public Key'
    # TODO: set Public Key as class variable to avoid building PEM every time
    # turn keycloak realm pub key into an actual openssl compat pub key.
    # keycloak_config = JSON.parse(File.read('config/keycloak.json'))
    keycloak_yml = YAML.load_file('config/keycloak.yml')
    unless keycloak_yml['realm_public_key']
      Keycloak.get_realm_public_key
      keycloak_yml = YAML.load_file('config/keycloak.yml')
      # puts "KEYCLOAK PUBLIC KEY IS", keycloak_yml['realm_public_key']
    end
    unless keycloak_yml['realm_public_key']
      return nil
    end
    @s = "-----BEGIN PUBLIC KEY-----\n"
    @s += keycloak_yml['realm_public_key'].scan(/.{1,64}/).join("\n")
    @s += "\n-----END PUBLIC KEY-----\n"
    key = OpenSSL::PKey::RSA.new @s
    key
  end

  # Public key used by realm encoded as a JSON Web Key (JWK).
  # This key can be used to verify tokens issued by Keycloak without making invocations to the server.
  def jwk_certs(realm=nil)
    http_path = "http://http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/realms/#{@@realm_name}/protocol/openid-connect/certs"
    url = URI(http_path)
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Get.new(url.to_s)
    response = http.request(request)
    # puts "RESPONSE", response.read_body
    response_json = parse_json(response.read_body)[0]
  end

  # "userinfo_endpoint":"http://localhost:8081/auth/realms/master/protocol/openid-connect/userinfo"
  def userinfo(token)
    # token = @@access_token
    http_path = "http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/realms/#{@@realm_name}/protocol/openid-connect/userinfo"
    url = URI(http_path)
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Get.new(url.to_s)
    request["authorization"] = 'bearer ' + token
    response = http.request(request)
    # puts "RESPONSE", response.read_body
    # response_json = parse_json(response.read_body)[0]
    return response.code, response.body
  end

  # Token Validation Endpoint
  # "token_introspection_endpoint":"http://localhost:8081/auth/realms/master/protocol/openid-connect/token/introspect"
  def token_validation(token, realm=nil)
    # url = URI("http://localhost:8081/auth/realms/master/clients-registrations/openid-connect/")
    url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/realms/#{@@realm_name}/protocol/openid-connect/token/introspect")
    # request = Net::HTTP::Post.new(url.to_s)
    # request = Net::HTTP::Get.new(url.to_s)
    # request["authorization"] = 'bearer ' + token
    # request["content-type"] = 'application/json'
    # body = {"token" => token}
    # request.body = body.to_json

    res = Net::HTTP.post_form(url, 'client_id' => @@client_name,
                              'client_secret' => @@client_secret,
                              'grant_type' => 'client_credentials', 'token' => token)

    # RESPONSE_INTROSPECT:
      logger.debug "Keycloak: Token validation code: #{res.code.to_s}"
    begin
      logger.debug "Keycloak: Token validation content: #{parse_json(res.body).to_s}"
    rescue
      logger.debug "Keycloak: Invalid token validation content"
    end
    return res.body, res.code
  end

  def register_user(user_form) #, username,firstname, lastname, email, credentials)
    refresh_adapter # Refresh admin token if expired
    body = user_form

    url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/users")
    http = Net::HTTP.new(url.host, url.port)

    request = Net::HTTP::Post.new(url.to_s)
    request["authorization"] = 'Bearer ' + @@access_token
    request["content-type"] = 'application/json'
    request.body = body.to_json
    response = http.request(request)
    logger.debug "Keycloak: Registration code #{response.code}"
    logger.debug "Keycloak: Registration message #{response.body.to_s}"
    # puts "REG CODE", response.code
    # puts "REG BODY", response.body
    if response.code.to_i != 201
      return nil, response.code.to_i, response.body
    end

    # GET new registered user Id
    url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/users?username=#{user_form['username']}")
    http = Net::HTTP.new(url.host, url.port)

    request = Net::HTTP::Get.new(url.to_s)
    request["authorization"] = 'Bearer ' + @@access_token
    request.body = body.to_json

    response = http.request(request)
    # puts "ID CODE", response.code
    # puts "ID BODY", response.body
    user_id = parse_json(response.body).first[0]["id"]
    # puts "USER ID", user_id

    # - Use the endpoint to setup temporary password of user (It will
    # automatically add requiredAction for UPDATE_PASSWORD
    url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/users/#{user_id}/reset-password")
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Put.new(url.to_s)
    request["authorization"] = 'Bearer ' + @@access_token
    request["content-type"] = 'application/json'

    credentials = user_form['credentials'][0]
    credentials['temporary'] = 'false'

    request.body = credentials.to_json
    response = http.request(request)
    # puts "CRED CODE", response.code
    # puts "CRED BODY", response.body
    if response.code.to_i != 204
      # halt response.code.to_i, response.body.to_s
      return nil, response.code.to_i, response.body.to_s
    end

    # - Then use the endpoint for update user and send the empty array of
    # requiredActions in it. This will ensure that UPDATE_PASSWORD required
    # action will be deleted and user won't need to update password again.
    url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/users/#{user_id}")
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Put.new(url.to_s)
    request["authorization"] = 'Bearer ' + @@access_token
    request["content-type"] = 'application/json'

    body = {"requiredActions" => []}

    request.body = body.to_json
    response = http.request(request)
    # puts "UPD CODE", response.code
    # puts "UPD BODY", response.body
    if response.code.to_i != 204
      # halt response.code.to_i, response.body.to_s
      return nil, response.code.to_i, response.body.to_s
    end

    return user_id, nil, nil
  end

  # "registration_endpoint":"http://localhost:8081/auth/realms/master/clients-registrations/openid-connect"
  def register_client (client_object)
    refresh_adapter # Refresh admin token if expired

    # url = URI("http://localhost:8081/auth/realms/master/clients-registrations/openid-connect/")
    url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/clients")
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Post.new(url.to_s)
    request["authorization"] = 'Bearer ' + @@access_token
    request["content-type"] = 'application/json'

    request.body = client_object.to_json
    response = http.request(request)
    # puts "CODE", response.code
    # puts "BODY", response.body
    response_json, code = parse_json(response.read_body)
    if response.code.to_i != 201
      halt response.code.to_i, {'Content-type' => 'application/json'}, response.body
    end

    # GET new registered Client Id
    url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/clients?clientId=#{client_object['clientId']}")
    http = Net::HTTP.new(url.host, url.port)

    request = Net::HTTP::Get.new(url.to_s)
    request["authorization"] = 'Bearer ' + @@access_token
    request.body = body.to_json

    response = http.request(request)
    # puts "ID CODE", response.code
    # puts "ID BODY", response.body
    client_id = parse_json(response.body).first[0]["id"]
    # puts "client ID", client_id
  end

  # "token_endpoint":"http://localhost:8081/auth/realms/master/protocol/openid-connect/token"
  def login_admin()
    @@address = 'localhost'
    @port = '8081'
    @uri = 'auth'
    @client_name = 'adapter'
    @client_secret = 'df7e816d-0337-4fbe-a3f4-7b5263eaba9f'
    @access_token = nil

    url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/protocol/openid-connect/token")

    res = Net::HTTP.post_form(url, 'client_id' => @client_name, 'client_secret' => @client_secret,
                              #                            'username' => "user",
                              #                            'password' => "1234",
                              'grant_type' => "client_credentials")

    if res.body['access_token']
      parsed_res, code = parse_json(res.body)
      @access_token = parsed_res['access_token']
      # puts "ACCESS_TOKEN RECEIVED" , parsed_res['access_token']
      parsed_res['access_token']
    end
  end

  # "token_endpoint":"http://localhost:8081/auth/realms/master/protocol/openid-connect/token"
  def login_user_broker
    # TODO:
    # curl -d "client_id=admin-cli" -d "username=user1" -d "password=1234" -d "grant_type=password" "http://localhost:8081/auth/realms/SONATA/protocol/openid-connect/token"
    client_id = "adapter"
    # @usrname = "user"
    # pwd = "1234"
    grt_type = "password"
    http_path = "http://http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/realms/#{@@realm_name}/protocol/openid-connect/token"
    idp_path = "http://localhost:8081/auth/realms/master/broker/github/login?"
    # puts `curl -X POST --data "client_id=#{client_id}&username=#{usrname}"&password=#{pwd}&grant_type=#{grt_type} #{http_path}`

    uri = URI(http_path)
    # uri = URI(idp_path)
    res = Net::HTTP.post_form(uri, 'client_id' => client_id, 'client_secret' => 'df7e816d-0337-4fbe-a3f4-7b5263eaba9f',
                              'username' => @usrname,
                              'password' => pwd,
                              'grant_type' => grt_type)
    puts "RES.BODY: ", res.body


    if res.body['access_token']
      # if env['HTTP_AUTHORIZATION']
      #  puts "env: ", env['HTTP_AUTHORIZATION']
      #  access_token = env['HTTP_AUTHORIZATION'].split(' ').last
      #  puts "access_token: ", access_token

      parsed_res, code = parse_json(res.body)
      @access_token = parsed_res['access_token']
      # puts "ACCESS_TOKEN RECEIVED", parsed_res['access_token']
      parsed_res['access_token']
    else
      401
    end
  end

  # "token_endpoint":"http://localhost:8081/auth/realms/master/protocol/openid-connect/token"
  def login(username=nil, credentials=nil)
    refresh_adapter # Refresh admin token if expired
    url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/realms/#{@@realm_name}/protocol/openid-connect/token")
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Post.new(url.to_s)
    request["authorization"] = 'Bearer ' + @@access_token
    request["content-type"] = 'application/x-www-form-urlencoded'

    #p "@client_name", @@client_name
    #p "@client_secret", @@client_secret

    case credentials['type']
      when 'password'
        # puts "IS A PASSWORD"
        request.set_form_data({'client_id' => @@client_name,
                               'client_secret' => @@client_secret,
                               'username' => username.to_s,
                               'password' => credentials['value'],
                               'grant_type' => credentials['type']})
      else
        # puts "IS A CLIENT"
        request.set_form_data({'client_id' => username,
                               'client_secret' => credentials['value'],
                               'grant_type' => credentials['type']})
    end

    response = http.request(request)
    # puts "LOG CODE", response.code
    # puts "LOG BODY", response.body

    unless response.code == '200'
      return response.code.to_i, response.body
    end

    parsed_res, errors = parse_json(response.body)
    # p "RESPONSE BODY"
    # puts parsed_res[0]['access_token']
    # halt 200, parsed_res['access_token'].to_json
    return 200, response.body
  end

  # "token_endpoint":"http://localhost:8081/auth/realms/master/protocol/openid-connect/token"
  def login_client(client_id, client_secret)
    #TODO: DEPRECATED
    url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/realms/#{@@realm_name}/protocol/openid-connect/token")
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Post.new(url.to_s)
    request["authorization"] = 'Bearer ' + @@access_token
    request["content-type"] = 'application/x-www-form-urlencoded'

    request.set_form_data({'client_id' => client_id,
                           'client_secret' => client_secret,
                           'grant_type' => 'client_credentials'})

    # puts "RES.HEADER: ", res.header
    # puts "RES.BODY: ", res.body

    if res.body['access_token']
      # if env['HTTP_AUTHORIZATION']
      # puts "env: ", env['HTTP_AUTHORIZATION']
      # access_token = env['HTTP_AUTHORIZATION'].split(' ').last
      # puts "access_token: ", access_token
      # {"access_token":"eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICIyRG1CZm1UaEJEa3NmNElMWVFnVEpSVmNRMDZJWEZYdWNOMzhVWk1rQ0cwIn0.eyJqdGkiOiJjYzY3MmUzYS1mZTVkLTQ4YjItOTQ4My01ZTYxZDNiNGJjMGEiLCJleHAiOjE0NzY0NDQ1OTAsIm5iZiI6MCwiaWF0IjoxNDc2NDQ0MjkwLCJpc3MiOiJodHRwOi8vbG9jYWxob3N0OjgwODEvYXV0aC9yZWFsbXMvU09OQVRBIiwiYXVkIjoiYWRtaW4tY2xpIiwic3ViIjoiYjFiY2M4YmQtOTJhMy00N2RkLTliOGUtZDY3NGQ2ZTU0ZjJjIiwidHlwIjoiQmVhcmVyIiwiYXpwIjoiYWRtaW4tY2xpIiwiYXV0aF90aW1lIjowLCJzZXNzaW9uX3N0YXRlIjoiNTkwYzlhNGUtYzljNC00OTU1LTg1NDAtYTViOTM2ODM5NjEzIiwiYWNyIjoiMSIsImNsaWVudF9zZXNzaW9uIjoiYjhkODI4ZjAtNWQ3Yy00NjI4LWEzOTEtNGQwNTY0MDNkNTRjIiwiYWxsb3dlZC1vcmlnaW5zIjpbXSwicmVzb3VyY2VfYWNjZXNzIjp7fSwibmFtZSI6InNvbmF0YSB1c2VyIHNvbmF0YSB1c2VyIiwicHJlZmVycmVkX3VzZXJuYW1lIjoidXNlcjEiLCJnaXZlbl9uYW1lIjoic29uYXRhIHVzZXIiLCJmYW1pbHlfbmFtZSI6InNvbmF0YSB1c2VyIiwiZW1haWwiOiJzb25hdGF1c2VyQHNvbmF0YS5uZXQifQ.T_GB_kBtZk-gmFNJ5rC2sJpNl4V3TUyhixq76hOi5MbgDbo_FfuKRomxviAeQi-RdJPIEffdzrVmaYXZVQHufpaYx9p90GQd3THQWMyZD50zMY40j-XlungaGKjizWNxaywvGXBMvDE_qYp0hr4Uewm4evO_NRRI1bWQLeaeJ3oHr1_p9vFZf5Kh8tZYR-dQSWuESvHhZrJAqHTzXlYYMRBqfjDyAgUhm8QbbtmDtPr0kkkIh1TmXevkZbm91mrS-9jWrS4zGZE5LiT5KdWnMs9P8FBR1p3vywwIu_z-0MF8_DIMJWa7ApZAXjtrszXAYVfCKsaisjjD9HacgpE-4w","expires_in":300,"refresh_expires_in":1800,"refresh_token":"eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICIyRG1CZm1UaEJEa3NmNElMWVFnVEpSVmNRMDZJWEZYdWNOMzhVWk1rQ0cwIn0.eyJqdGkiOiIyOTRmZjc5Yy01ZWIxLTQwNDgtYmM1NS03NjcwOGU1Njg1YzMiLCJleHAiOjE0NzY0NDYwOTAsIm5iZiI6MCwiaWF0IjoxNDc2NDQ0MjkwLCJpc3MiOiJodHRwOi8vbG9jYWxob3N0OjgwODEvYXV0aC9yZWFsbXMvU09OQVRBIiwiYXVkIjoiYWRtaW4tY2xpIiwic3ViIjoiYjFiY2M4YmQtOTJhMy00N2RkLTliOGUtZDY3NGQ2ZTU0ZjJjIiwidHlwIjoiUmVmcmVzaCIsImF6cCI6ImFkbWluLWNsaSIsImF1dGhfdGltZSI6MCwic2Vzc2lvbl9zdGF0ZSI6IjU5MGM5YTRlLWM5YzQtNDk1NS04NTQwLWE1YjkzNjgzOTYxMyIsImNsaWVudF9zZXNzaW9uIjoiYjhkODI4ZjAtNWQ3Yy00NjI4LWEzOTEtNGQwNTY0MDNkNTRjIiwicmVzb3VyY2VfYWNjZXNzIjp7fX0.WGHvTiVc08xuVCDM5YLlvIzvBgz0aJ3OY3-VGmKSyI-fDLfbp9LSLkPsIqiKO9mDjybSfEkrNmPBd60lWecUC43DacVhVbiLEU9cJdMnjQjrU0P3wg1HFQmcG8exylJMzWoAbJzm893SP-kgKVYCnbQ55Os1-oT1ClHr3Ts6BHVgz5FWrc3dk6DqOrGAxmoJLQUgNJ5jdF-udt-j81OcBTtC3b-RXFXlRu3AyJ0p-UPiu4_HkKBVdg0pmycuN0v0it-TxR_mlM9lhvdVMGXLD9_-PUgklfc6XisdCrGa_b9r06aQCiekXGWptLoFF1Oz__g2_v4Gsrzla5YKBZzGfA","token_type":"bearer","id_token":"eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICIyRG1CZm1UaEJEa3NmNElMWVFnVEpSVmNRMDZJWEZYdWNOMzhVWk1rQ0cwIn0.eyJqdGkiOiI5NWVmMGY0Yi1lODIyLTQwMTAtYWU1NS05N2YyYTEzZWViMzkiLCJleHAiOjE0NzY0NDQ1OTAsIm5iZiI6MCwiaWF0IjoxNDc2NDQ0MjkwLCJpc3MiOiJodHRwOi8vbG9jYWxob3N0OjgwODEvYXV0aC9yZWFsbXMvU09OQVRBIiwiYXVkIjoiYWRtaW4tY2xpIiwic3ViIjoiYjFiY2M4YmQtOTJhMy00N2RkLTliOGUtZDY3NGQ2ZTU0ZjJjIiwidHlwIjoiSUQiLCJhenAiOiJhZG1pbi1jbGkiLCJhdXRoX3RpbWUiOjAsInNlc3Npb25fc3RhdGUiOiI1OTBjOWE0ZS1jOWM0LTQ5NTUtODU0MC1hNWI5MzY4Mzk2MTMiLCJhY3IiOiIxIiwibmFtZSI6InNvbmF0YSB1c2VyIHNvbmF0YSB1c2VyIiwicHJlZmVycmVkX3VzZXJuYW1lIjoidXNlcjEiLCJnaXZlbl9uYW1lIjoic29uYXRhIHVzZXIiLCJmYW1pbHlfbmFtZSI6InNvbmF0YSB1c2VyIiwiZW1haWwiOiJzb25hdGF1c2VyQHNvbmF0YS5uZXQifQ.FrwYdv1S8mqivHjsyA93ycl10z2tisVJraUGcBJzle060nCO69ZEa0fzrMMCbSkjY1JAwjP92d7_ixuWpcUVvQLkesxKOgcBc8LVhClyh3__8p46kIwfrJYMZQt0cJ6f6nASX1yaySE9sDgl3ElkW0vz-i9vhEXkIh6m-EuC7lH0ZIIL-39-occssq7G5hDleDUMThno8sEsl8rgtV-GdAfjKIwi-yOB0X8K1RrfDarccwA3XB0R8nHAbInZGsrF114KsBuaEvWjKki4m86xFkfPPuSlvWaVRtCziiTBqrBZ_Qna6wI9FfAOiTzPXE5AfFtDowih6d-26kT_jd_7GA","not-before-policy":0,"session_state":"590c9a4e-c9c4-4955-8540-a5b936839613"}

      parsed_res, code = parse_json(res.body)
      @access_token = parsed_res['access_token']
      # puts "ACCESS_TOKEN RECEIVED", parsed_res['access_token']
      parsed_res['access_token']
    else
      halt 401
    end
  end

  # Method that allows end-user authentication through authorized browser
  # "authorization_endpoint":"http://localhost:8081/auth/realms/master/protocol/openid-connect/auth"
  def authorize_browser(token=nil, realm=nil)
    client_id = "adapter"
    @usrname = "user"
    pwd = "1234"
    grt_type = "password"

    query = "response_type=code&scope=openid%20profile&client_id=adapter&redirect_uri=http://127.0.0.1/"
    http_path = "http://http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/realms/#{@@realm_name}/protocol/openid-connect/auth" + "?" + query
    url = URI(http_path)
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Get.new(url.to_s)
    #request["authorization"] = 'bearer ' + token

    response = http.request(request)
    # p "RESPONSE", response.body

    File.open('codeflow.html', 'wb') do |f|
      f.puts response.read_body
    end
  end

  # "end_session_endpoint":"http://localhost:8081/auth/realms/master/protocol/openid-connect/logout"
  def logout(user_token, user=nil, realm=nil)
    refresh_adapter # Refresh admin token if expired
    # user = token['sub']#'971fc827-6401-434e-8ea0-5b0f6d33cb41'
    # code, data = userinfo(user_token)
    user = parse_json(userinfo(user_token)[1])[0]
    # p "SUB[0]", user['sub']
    # http_path = "http://localhost:8081/auth/realms/master/protocol/openid-connect/logout"
    http_path ="http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/users/#{user['sub']}/logout"
    url = URI(http_path)
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Post.new(url.to_s)
    request["authorization"] = 'bearer ' + @@access_token
    request["content-type"] = 'application/x-www-form-urlencoded'
    # request["content-type"] = 'application/json'

    # request.set_form_data({'client_id' => 'adapter',
    #                       'client_secret' => 'df7e816d-0337-4fbe-a3f4-7b5263eaba9f',
    #                       'username' => 'user',
    #                       'password' => '1234',
    #                       'grant_type' => 'password'})
    # request.set_form_data('refresh_token' => token)

    # _remove_all_user_sessions_associated_with_the_user

    # request.body = body.to_json

    response = http.request(request)
    # puts "RESPONSE CODE", response.code
    # puts "RESPONSE BODY", response.body
    # response_json = parse_json(response.read_body)[0]
    return response.code.to_i
  end

  def authenticate(client_id, username, password, grant_type)
    http_path = "http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/realms/#{@@realm_name}/protocol/openid-connect/token"
    # puts `curl -X POST --data "client_id=#{client_id}&username=#{usrname}"&password=#{pwd}&grant_type=#{grt_type} #{http_path}`

    uri = URI(http_path)
    res = nil
    case grant_type
      when 'password' # -> user
        res = Net::HTTP.post_form(uri, 'client_id' => client_id,
                                  'client_secret' => password,
                                  'grant_type' => grant_type)

      when 'client_credentials' # -> service
        res = Net::HTTP.post_form(uri, 'client_id' => client_id,
                                  'username' => username,
                                  'password' => password,
                                  'grant_type' => grant_type)
      else
        halt 400
    end

    if res.body['id_token']
      parsed_res, code = parse_json(res.body)
      id_token = parsed_res['id_token']
      # puts "ID_TOKEN RECEIVED"# , parsed_res['access_token']
    else
      halt 401, "ERROR: ACCESS DENIED!"
    end
  end

  def authorize?(user_token, request)
    refresh_adapter
    # => Check token
    public_key = get_public_key
    # p "SETTINGS", settings.keycloak_pub_key
    token_payload, token_header = decode_token(user_token, public_key)
    # puts "payload", token_payload

    # => evaluate request
    # Find mapped resource to path
    # required_role is build following next pattern:
    # operation
    # operation_resource
    # operation_resource_type

    log_file = File.new("#{settings.root}/log/#{settings.environment}.log", 'a+')
    STDOUT.reopen(log_file)
    STDOUT.sync = true

    logger.debug "Adapter: Token Payload: #{token_payload.to_s}, Token Header: #{token_header.to_s}"

    required_role = 'role_' + request['operation'] + '-' + request['resource']
    # p "REQUIRED ROLE", required_role
    logger.debug "Adapter: Required Role: #{required_role}"

    # => Check token roles
    begin
      token_realm_access_roles = token_payload['realm_access']['roles']
    rescue
      json_error(403, 'No permissions')
    end

    # TODO: Resource access roles (services) will be implemented later
    token_resource_access_resources = token_payload['resource_access']
    # .
    # .
    # .
    # TODO: Evaluate special roles (customer,developer,etc...)
    # .
    # .
    # .

    p "realm_access_roles", token_realm_access_roles
    code, realm_roles = get_realm_roles

    p "realm_roles", realm_roles
    parsed_realm_roles, errors = parse_json(realm_roles)
    # p "Realm_roles_PARSED", parsed_realm_roles

    authorized = false
    token_realm_access_roles.each { |role|
      # puts "ROLE TO INSPECT", role

      token_role_repr = parsed_realm_roles.find {|x| x['name'] == role}
      unless token_role_repr
        json_error(403, 'No permissions')
      end

      puts "ROLE_DESC", token_role_repr['description']
      role_perms = token_role_repr['description'].tr('${}', '').split(',')
      puts "ROLE_PERM", role_perms

      if role_perms.include?(required_role)
        authorized = true
      end
    }

    STDOUT.sync = false

    #=> Response => 20X or 40X
    case authorized
      when true
        return 200, nil
      else
        return 403, 'User is not authorized'
    end
  end

  def refresh_service(token, credentials)
    #=> Check if token.expired?
    code = is_expired?
    case code
      when 'OK'
        # puts "OK"
        return
      else
        #=> Then GET new token
       # TODO: OPTIONAL
    end
  end

  def refresh_adapter()
    logger.debug 'Adapter: Checking Adapter token status'
    if defined?@@access_token
      # Check if token has expired
      code = is_expired?
      case code
        when 200
          # Then check if token is still valid
          res, code = token_validation(@@access_token)
          if code.to_i == 200
            result = is_active?(res)
            case result
              # When the token is inactive
              when false
                # Then GET a new token
                logger.debug 'Adapter: Refreshing Adapter token'
                result = Keycloak.get_adapter_token
                if result.is_a?(Integer)
                  halt result
                end
                @@access_token = result
                logger.debug "New Access Token saved #{@@access_token}"
                return 200, @@access_token
              else
                logger.debug 'Adapter: Adapter token is active'
                return 200, @@access_token
            end
          end
          logger.debug 'Adapter: Adapter token is active'
          return 200, @@access_token
        else
          # Then GET a new token
          logger.debug 'Adapter: Refreshing Adapter token'
          result = Keycloak.get_adapter_token
          if result.is_a?(Integer)
            halt result
          end
          @@access_token = result
          logger.debug "New Access Token saved #{@@access_token}"
          return 200, @@access_token
      end
    end
    logger.debug 'Adapter: Adapter token not found'
  end

  def set_user_roles(user_type, user_id)
    refresh_adapter
    # Search roles
    code, realm_roles = get_realm_roles
    role_data = parse_json(realm_roles)[0].find {|role| role['name'] == user_type}
    # p "ROLE DATA", role_data
    # Compare user_type with roles
    unless role_data
      return 401, {'Error' => 'User type is not allowed'}
    end

    # Add role from roles to user_id
    ##POST rest-api/admin/realms/{realm}/users/{id}/role-mappings/realm
    http_path = "http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/users/#{user_id}/role-mappings/realm"
    url = URI(http_path)
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Post.new(url.to_s)
    request["authorization"] = 'bearer ' + @@access_token
    request["content-type"] = 'application/json'
    body = []
    request.body = (body << role_data).to_json

    response = http.request(request)
    # log_file = File.new("#{settings.root}/log/#{settings.environment}.log", 'a+')
    # STDOUT.reopen(log_file)
    # STDOUT.sync = true
    # p "CODE", response.code
    # p "BODY", response.body
    # STDOUT.sync = false
    if response.code.to_i != 204
      return response.code.to_i, response.body
    else
      return response.code.to_i, nil
    end
  end

  def set_user_groups(role_attr, user_id)
    # Assign group based on attr
    group_list = get_groups
    group_names = get_groups_names(group_list, role_attr)
    # group_name = Adapter.assign_group(attr)

    # Search roles
    group_names.each { |group_name|
      group_data, errors = parse_json(get_groups({'name' => group_name}))
      # groups = get_groups(attribute)
      # group_data = parse_json(realm_roles)[0].find {|group| group['name'] == attribute}
      # p "GROUP DATA", group_data
      # Compare user_type with roles
      unless group_data
        return 401, {'Error' => 'User type is not allowed'}
      end

      # Add user to group
      ## PUT /admin/realms/{realm}/users/{id}/groups/{groupId}
      http_path = "http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/users/#{user_id}/groups/#{group_data['id']}"
      url = URI(http_path)
      http = Net::HTTP.new(url.host, url.port)
      request = Net::HTTP::Put.new(url.to_s)
      request["authorization"] = 'bearer ' + @@access_token
      # request["content-type"] = 'application/json'
      # body = []
      # request.body = (body << role_data).to_json
      # p "ADDING USER TO GROUP"

      response = http.request(request)
      # p "CODE", response.code
      # p "BODY", response.body

      if response.code != '204'
        return response.code.to_i, response.body
      end
    }
    return 204 , nil
  end

  def set_service_roles(client_id)
    refresh_adapter
    # Search client ID by cliendID name
    logger.debug "Keycloak: Getting roles for #{client_id}"
    query = {'name' => client_id}
    client_data, errors = parse_json(get_clients(query))
    logger.debug "Keycloak: Client data #{client_data}"
    return nil, nil, 401, 'Service not allowed' if errors

    # Get realm-level roles that are available to attach to this client’s scope
    # GET http://localhost:8081/auth/admin/realms/{realm}/clients/{id}/scope-mappings/realm/available
    http_path = "http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/clients/#{client_data['id']}/scope-mappings/realm/available"
    url = URI(http_path)
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Get.new(url.to_s)
    request["authorization"] = 'bearer ' + @@access_token

    response = http.request(request)
    # p "REALM AVAILABLE SCOPE", parse_json(response.body)[0]

    # TODO: Rework this process (predefined service roles)!!!
    logger.debug "Keycloak: Available roles: #{parse_json(response.body)}"
    role_data = parse_json(response.body)[0].find {|role| role['name'] == query['name']}
    # p "ROLE DATA", role_data
    logger.debug "Keycloak: Client role data is: #{role_data}"
    unless role_data
      return nil, nil, 401, {'Error'=> 'Service not allowed'}
    end

    # Add a set of realm-level roles to the client’s scope
    # POST /admin/realms/{realm}/clients/{id}/scope-mappings/realm
    http_path = "http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/clients/#{client_data['id']}/scope-mappings/realm"
    url = URI(http_path)
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Post.new(url.to_s)
    request["authorization"] = 'bearer ' + @@access_token
    request["content-type"] = 'application/json'
    body = []
    request.body = (body << role_data).to_json

    response = http.request(request)
    # p "CODE", response.code
    # p "BODY", response.body
    logger.debug "Keycloak: Set service client role response is: #{response.code}"

    if response.code.to_i != 204
      return nil, nil, response.code.to_i, response.body.to_s
    else
      return client_data, role_data, nil, nil
    end
    # Returns the roles for the client that can be associated with the client's scope
    # GET /admin/realms/{realm}/clients/{id}/scope-mappings/clients/{client}/available
    # Get realm-level roles that are available to attach to this client’s scope
    # http_path = "http://localhost:8081/auth/admin/realms/master/clients/#{client_data['id']}/scope-mappings/realm/available"
    # url = URI(http_path)
    # http = Net::HTTP.new(url.host, url.port)
    # request = Net::HTTP::Get.new(url.to_s)
    # request["authorization"] = 'bearer ' + @@access_token
    # response = http.request(request)
  end

  def set_service_account_roles(client_data, role_data)
    refresh_adapter
    # puts "CLIENT ID", client_data
    # Get a user dedicated to the service account
    # GET /admin/realms/{realm}/clients/{id}/service-account-user
    http_path = "http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/clients/#{client_data}/service-account-user"
    url = URI(http_path)
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Get.new(url.to_s)
    request["authorization"] = 'bearer ' + @@access_token

    response = http.request(request)
    # p "CODE", response.code
    # p "BODY", response.body

    logger.debug "Keycloak: Set service account id response is: #{response.code}"
    parsed_user, errors = parse_json(response.body)

    # Add role from roles to user_id
    ## POST rest-api/admin/realms/{realm}/users/{id}/role-mappings/realm
    http_path = "http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/users/#{parsed_user['id']}/role-mappings/realm"
    url = URI(http_path)
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Post.new(url.to_s)
    request["authorization"] = 'bearer ' + @@access_token
    request["content-type"] = 'application/json'
    body = []
    request.body = (body << role_data).to_json

    response = http.request(request)
    # p "CODE", response.code
    # p "BODY", response.body

    logger.debug "Keycloak: Set service account role response is: #{response.code}"
    if response.code.to_i == 204
      return response.code.to_i, nil
    else
      return response.code.to_i, response.body
    end
  end

  def delete_user(username)
    refresh_adapter
    # GET new registered user Id
    url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/users?username=#{username}")
    http = Net::HTTP.new(url.host, url.port)

    request = Net::HTTP::Get.new(url.to_s)
    request["authorization"] = 'Bearer ' + @@access_token
    request.body = body.to_json

    response = http.request(request)
    begin
      user_id = parse_json(response.body).first[0]["id"]
    rescue
      json_error(response.code.to_i, response.body.to_s)
    end

    url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/users/#{user_id}")
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Delete.new(url.to_s)
    request["authorization"] = 'Bearer ' + @@access_token
    request["content-type"] = 'application/json'

    response = http.request(request)
    if response.code.to_i != 204
      halt response.code.to_i, {'Content-type' => 'application/json'}, response.body
    end
  end

  def delete_user_by_id(username, user_id)
    refresh_adapter
    if user_id.nil?
     # GET new registered user Id
      url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/users?username=#{username}")
      http = Net::HTTP.new(url.host, url.port)

      request = Net::HTTP::Get.new(url.to_s)
      request["authorization"] = 'Bearer ' + @@access_token
      request.body = body.to_json

      response = http.request(request)
      begin
        user_id = parse_json(response.body).first[0]["id"]
      rescue
        return response.code.to_i, response.body.to_json
      end
    end

    url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/users/#{user_id}")
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Delete.new(url.to_s)
    request["authorization"] = 'Bearer ' + @@access_token
    request["content-type"] = 'application/json'

    response = http.request(request)
    if response.code.to_i != 204
      return response.code.to_i, response.body.to_json
    end
    return nil, user_id
  end

  def delete_client(clientId)
    # logger.debug "Keycloak: entered delete_client id: #{clientId}"
    # GET new registered client Id (Name)
    url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/clients?clientId=#{clientId}")
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Get.new(url.to_s)
    request["authorization"] = 'Bearer ' + @@access_token
    response = http.request(request)
    # logger.debug "Keycloak: delete client id code response #{response.code}"
    # logger.debug "#{response.body}"
    begin
      client_id = parse_json(response.body).first[0]["id"]
    rescue
      # ClientId already is the 'id' of the client
      client_id = clientId
    end

    # refresh_adapter # Refresh admin token if expired
    url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/clients/#{client_id}")
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Delete.new(url.to_s)
    request["authorization"] = 'Bearer ' + @@access_token
    request["content-type"] = 'application/json'
    response = http.request(request)
    # logger.debug "Keycloak: delete client result code #{response.code}"
    # logger.debug "#{response.body}"
    if response.code.to_i != 204
      halt response.code.to_i, {'Content-type' => 'application/json'}, response.body
    end
  end

  def delete_realm_role(role)
    # Delete a role by name
    # DELETE /admin/realms/{realm}/roles/{role-name}
  end

  def update_user(username, user_id, body)
    refresh_adapter
    if user_id.nil?
      # GET new registered user Id
      url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/users?username=#{username}")
      http = Net::HTTP.new(url.host, url.port)
      request = Net::HTTP::Get.new(url.to_s)
      request["authorization"] = 'Bearer ' + @@access_token
      request.body = body.to_json
      response = http.request(request)
      begin
        user_id = parse_json(response.body).first[0]["id"]
      rescue
        return response.code.to_i, response.body.to_json
      end
    end

    # Update the user
    # PUT /admin/realms/{realm}/clients/{id}/users
    # Body rep = UserRepresentation
    url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/users/#{user_id}")
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Put.new(url.to_s)
    request["authorization"] = 'Bearer ' + @@access_token
    request["content-type"] = 'application/json'
    request.body = body.to_json
    response = http.request(request)
    if response.code.to_i != 204
      return response.code.to_i, response.body.to_s
    end
    return nil, user_id
  end

  def update_user_pkey(user_id, attrs)
    url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/users/#{user_id}")
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Put.new(url.to_s)
    request["authorization"] = 'Bearer ' + @@access_token
    request["content-type"] = 'application/json'
    body = {"attributes" => attrs}
    request.body = body.to_json
    response = http.request(request)
    log.debug "update_user_pkey CODE #{response.code}"
    log.debug "update_user_pkey BODY #{response.body}"

    if response.code.to_i != 204
      # halt response.code.to_i, response.body.to_s
      return nil, response.code.to_i, response.body.to_s
    end
  end

  def update_client()
    # TODO: Implement
    # Update the client
    # PUT /admin/realms/{realm}/clients/{id}
    # Body rep = ClientRepresentation
  end

  def get_groups(query=nil)
    # puts "GET_GROUPS_QUERY", query
    # GET /admin/realms/{realm}/groups
    # GroupRepresentation
    # id, name, path, attributes, realmRoles, clientRoles, subGroups
    refresh_adapter # Refresh admin token if expired
    # TODO: IT ONLY SUPPORTS QUERIES BY ID, NAME (GROUPID)
    url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/groups")
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Get.new(url.to_s)
    request["authorization"] = 'Bearer ' + @@access_token
    request["content-type"] = 'application/json'

    response = http.request(request)
    # p "RESPONSE", response.body
    # p "CODE", response.code
    # p "RESPONSE.read_body222", parse_json(response.read_body)[0]
    group_list = parse_json(response.read_body)[0]

    if query && query.key?('name')
      # puts "NAME PRESENT?", query['name']
      group_data = group_list.find {|group| group['name'] == query['name'] }
      group_data.to_json
    else
      group_list
    end
  end

  def get_groups_names(group_list, role)
    role_group_map = []
    group_list.each { |k|
      if k['id']
        url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/groups/#{k['id']}")
        http = Net::HTTP.new(url.host, url.port)
        request = Net::HTTP::Get.new(url.to_s)
        request["authorization"] = 'Bearer ' + @@access_token
        response = http.request(request)
        group_data = parse_json(response.body)[0]
        begin
          group_data['attributes']['roles'].each { |role_name|
            if role_name == role
              role_group_map << group_data['name']
            end
          }
        rescue
          nil
        end
      end
    }
    role_group_map
  end

  def get_clients(query=nil)
    logger.debug "Keycloak: getting clients with query #{query}"
    refresh_adapter # Refresh admin token if expired
    url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/clients")
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Get.new(url.to_s)
    request["authorization"] = 'Bearer ' + @@access_token
    request["content-type"] = 'application/json'

    response = http.request(request)
    # p "RESPONSE", response.body
    # p "CODE", response.code
    # p "RESPONSE.read_body222", parse_json(response.read_body)[0]
    client_list = parse_json(response.read_body)[0]
    logger.debug "Keycloak: clients list #{client_list}"
    if query['name']
      # puts "NAME PRESENT?", query['name']
      client_data = client_list.find {|client| client['clientId'] == query['name'] }
      logger.debug "Keycloak: client data #{client_data}"
      return [].to_json if client_data.nil?
      client_data.to_json
    elsif query['id']
      client_data = client_list.find {|client| client['id'] == query['id'] }
      logger.debug "Keycloak: client data #{client_data}"
      return [].to_json if client_data.nil?
      client_data.to_json
    else
      response.body
    end
  end

  def get_client_service_account
    # Get a user dedicated to the service account
    # GET /admin/realms/{realm}/clients/{id}/service-account-user
  end

  def get_realm_roles(keyed_query=nil)
    logger.debug 'Adapter: getting realm roles'
    refresh_adapter # Refresh admin token if expired
    # Get all roles for the realm or client
    # query = Rack::Utils.build_query(keyed_query) # QUERIES NOT SUPPORTED
    url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/roles")
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Get.new(url.to_s)
    request["authorization"] = 'Bearer ' + @@access_token

    response = http.request(request)
    # p "RESPONSE.read_body", response.read_body
    # p "CODE", response.code
    # parsed_res, code = parse_json(response.body)
    return response.code, response.body
  end

  def get_client_roles(client, keyed_query=nil)
    logger.debug 'Adapter: getting client roles'
    # Get all roles for the realm or client
    url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/clients/#{client}/roles")
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Get.new(url.to_s)
    request["authorization"] = 'Bearer ' + @@access_token

    response = http.request(request)
    # p "RESPONSE.read_body", response.read_body
    # p "CODE", response.code
    parsed_res, errors = parse_json(response.body)
    # p "RESPONSE_PARSED", parsed_res
    parsed_res
  end

  def get_role_details(role)
    logger.debug 'Adapter: getting role details'
    refresh_adapter # Refresh admin token if expired
    # url = URI("http://localhost:8081/auth/admin/realms/#{realm}/clients/#{id}/roles/#{role}")
    url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/roles/#{role}")
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Get.new(url.to_s)
    request["authorization"] = 'Bearer ' + @@access_token

    response = http.request(request)
    # p "RESPONSE.read_body", response.read_body
    # p "CODE", response.code
    parsed_res, code = parse_json(response.body)
    # p "RESPONSE_PARSED", parsed_res
    parsed_res
  end

  def get_users(keyed_query)
    logger.debug 'Adapter: getting users'
    refresh_adapter # Refresh admin token if expired
    # puts "KEYED_QUERY", keyed_query
    # Get all users for the realm
    query = Rack::Utils.build_query(keyed_query)
    logger.debug "Adapter: Built query #{query}"
    uri = "http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/users?" + query
    url = URI(uri)
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Get.new(url.to_s)
    request["authorization"] = 'Bearer ' + @@access_token

    response = http.request(request)
    # p "CODE", response.code
    parsed_res, code = parse_json(response.body)
    logger.debug "Adapter: Parsed response #{parsed_res}"
    # p "RESPONSE_PARSED", parsed_res
    response.body
  end

  def get_user(id_param)
    logger.debug 'Adapter: getting user info'
    refresh_adapter # Refresh admin token if expired
    # puts "KEYED_QUERY", keyed_query
    # Get all users for the realm
    # query = Rack::Utils.build_query(keyed_query)
    logger.debug "Adapter: User ID query #{id_param}"
    uri = "http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/users/#{id_param}"
    url = URI(uri)
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Get.new(url.to_s)
    request["authorization"] = 'Bearer ' + @@access_token

    response = http.request(request)
    # p "CODE", response.code
    parsed_res, code = parse_json(response.body)
    logger.debug "Adapter: Parsed response #{parsed_res}"
    # p "RESPONSE_PARSED", parsed_res
    return response.code, response.body
  end

  def get_user_id(username)
    logger.debug 'Adapter: getting user ID'
    refresh_adapter # Refresh admin token if expired
    # GET new registered user Id
    url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/users?username=#{username}")
    http = Net::HTTP.new(url.host, url.port)

    request = Net::HTTP::Get.new(url.to_s)
    request["authorization"] = 'Bearer ' + @@access_token
    request.body = body.to_json

    response = http.request(request)
    # puts "ID CODE", response.code
    # puts "ID BODY", response.body
    begin
      user_id = parse_json(response.body).first[0]["id"]
    rescue
      user_id = nil
    end
    logger.debug "Adapter: UserId is #{user_id}"
    user_id
    # puts "USER ID", user_id
  end

  def get_client_id(clientId)
    logger.debug 'Adapter: getting client ID'
    refresh_adapter # Refresh admin token if expired
    # GET service client Id
    url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/clients?clientId=#{clientId}")
    http = Net::HTTP.new(url.host, url.port)

    request = Net::HTTP::Get.new(url.to_s)
    request["authorization"] = 'Bearer ' + @@access_token
    request.body = body.to_json

    response = http.request(request)
    # puts "ID CODE", response.code
    # puts "ID BODY", response.body
    client_id = parse_json(response.body).first[0]["id"]
  end

  def get_sessions(account_type, id)
    logger.debug 'Adapter: getting sessions'
    refresh_adapter # Refresh admin token if expired
    case account_type
      when 'user'
        # GET /admin/realms/{realm}/clients/{id}/user-sessions
        url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/clients/#{id}/user-sessions")
        http = Net::HTTP.new(url.host, url.port)
      else #'service'
        url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/client-session-stats")
        http = Net::HTTP.new(url.host, url.port)
    end
    request = Net::HTTP::Get.new(url.to_s)
    request["authorization"] = 'bearer ' + @@access_token
    response = http.request(request)
    logger.debug "Adapter: Session response code:#{response.code}"
    logger.debug "Adapter: Session response content:#{response.body}"
    # p "CODE_SESSIONS", response.code
    # p "BODY_SESSIONS", response.body
    return response.code, response.body
  end

  def get_user_sessions(user_Id)
    # Get sessions associated with the user
    # GET /admin/realms/{realm}/users/{id}/sessions
    logger.debug 'Adapter: getting client ID'
    refresh_adapter # Refresh admin token if expired
    # GET service client Id
    url = URI("http://#{@@address.to_s}:#{@@port.to_s}/#{@@uri.to_s}/admin/realms/#{@@realm_name}/users/#{user_Id}/sessions")
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Get.new(url.to_s)
    request["authorization"] = 'Bearer ' + @@access_token
    response = http.request(request)
    # puts "ID CODE", response.code
    # puts "ID BODY", response.body
    logger.debug "Adapter: User session response code:#{response.code}"
    logger.debug "Adapter: User session response content:#{response.body}"
    return response.code, response.body
  end

  def is_active?(introspect_res)
    token_evaluation = JSON.parse(introspect_res)
    # puts "token_evaluation", token_evaluation.to_s
    case token_evaluation['active']
      when true
        # p "ACTIVE CONTENTS TRUE", token_evaluation['active']
        logger.info 'Keycloak: Evaluated token is active'
        true
      else
        # p "ACTIVE CONTENTS FALSE", token_evaluation['active']
        logger.info 'Keycloak: Evaluated token is inactive'
        false
    end
  end

  def is_expired?
    public_key = get_public_key
    logger.debug 'Adapter: Decoding Access Token'
    begin
      decoded_payload, decoded_header = JWT.decode @@access_token, public_key, true, { :algorithm => 'RS256' }
      # puts "DECODED_HEADER: ", decoded_header
      logger.debug 'Adapter: Access Token decoded successfully'
      # puts "DECODED_PAYLOAD: ", decoded_payload
      response = 200
    # if expired token, refresh adapter token
    rescue JWT::DecodeError
      logger.debug 'Adapter: Decoding Access Token DecodeError'
      response = 'DecodeError'
    rescue JWT::ExpiredSignature
      logger.debug 'Adapter: Decoding Access Token ExpiredSignature Error'
      response = 'ExpiredSignature'
    rescue JWT::InvalidIssuerError
      logger.debug 'Adapter: Decoding Access Token InvalidIssuerError'
      response = 'InvalidIssuerError'
    rescue JWT::InvalidIatError
      logger.debug 'Adapter: Decoding Access Token InvalidIatError'
      response = 'InvalidIatError'
    end
    response
  end

  def token_expired?(token)
    public_key = get_public_key
    logger.debug 'Adapter: Decoding Access Token'
    begin
      decoded_payload, decoded_header = JWT.decode token, public_key, true, { :algorithm => 'RS256' }
      # puts "DECODED_HEADER: ", decoded_header
      logger.debug 'Adapter: Access Token decoded successfully'
      # puts "DECODED_PAYLOAD: ", decoded_payload
      response = 200
        # if expired token, refresh adapter token
    rescue JWT::DecodeError
      logger.debug 'Adapter: Decoding Access Token DecodeError'
      response = 'DecodeError'
    rescue JWT::ExpiredSignature
      logger.debug 'Adapter: Decoding Access Token ExpiredSignature Error'
      response = 'ExpiredSignature'
    rescue JWT::InvalidIssuerError
      logger.debug 'Adapter: Decoding Access Token InvalidIssuerError'
      response = 'InvalidIssuerError'
    rescue JWT::InvalidIatError
      logger.debug 'Adapter: Decoding Access Token InvalidIatError'
      response = 'InvalidIatError'
    end
    response
  end

  def process_request(uri, method)
    # TODO: REVAMP EVALUATION FUNCTION
    log_file = File.new("#{settings.root}/log/#{settings.environment}.log", 'a+')
    STDOUT.reopen(log_file)
    STDOUT.sync = true

    # Parse uri path
    path = URI(uri).path.split('/')[1]
    p "path", path

    # Find mapped resource to path
    # TODO: CHECK IF IS A VALID RESOURCE FROM DATABASE
    resources = @@auth_mappings['resources']
    p "RESOURCES", resources

    resource = nil
    # p "PATHS", @@auth_mappings['paths']
    @@auth_mappings['paths'].each { |k, v|
      puts "k, v", k, v
      v.each { |kk, vv|
        puts "kk, vv", kk, vv
        if kk == path
          p "Resource found", k, kk
          resource = [k, kk]
          break
        end
      }
      p "FOUND_RESOURCE", resource
      if resource
        break
      end
    }
    unless resource
      json_error(403, 'The resource is not available')
    end

    unless @@auth_mappings['paths'][resource[0]][resource[1]].key?(method)
      json_error(403, 'The resource operation is not available')
    else
      operation = @@auth_mappings['paths'][resource[0]][resource[1]][method]
      puts "FOUND_OPERATION", operation
      STDOUT.sync = false
      request = {"resource" => resource[0], "type" => resource[1], "operation" => operation}
    end
  end
end
