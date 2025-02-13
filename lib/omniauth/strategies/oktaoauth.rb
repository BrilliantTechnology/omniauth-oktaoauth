# frozen_string_literal: true

require 'omniauth-oauth2'

module OmniAuth
  module Strategies
    class Oktaoauth < OmniAuth::Strategies::OAuth2


      DEFAULT_SCOPE = %[openid profile email].freeze

      option :name, 'oktaoauth'

      option :skip_jwt, false
      option :jwt_leeway, 60

      option :client_options, {
        site:          "configure this part ins client options with devise",
        authorize_url: "configure this part in client options with devise",
        token_url:     "configure this part in client options with devise",
        response_type: 'id_token'
      }

      option :scope, DEFAULT_SCOPE

      uid { raw_info['sub'] }

      info do
        {
          name:       raw_info['name'],
          email:      raw_info['email'],
          first_name: raw_info['given_name'],
          last_name:  raw_info['family_name'],
          image:      raw_info['picture']
        }
      end

      extra do
        hash = {}

        hash[:raw_info] = raw_info unless skip_info?
        hash[:id_token] = access_token.token
        if !options[:skip_jwt] && !access_token.token.nil?
          hash[:id_info] = validated_token(access_token.token)
        end
        hash
      end

      alias :oauth2_access_token :access_token

      def access_token
        ::OAuth2::AccessToken.new(client, oauth2_access_token.token, {
          :expires_in => oauth2_access_token.expires_in,
          :expires_at => oauth2_access_token.expires_at
        })
      end

      def raw_info
        uri = URI(options[:issuer])
        @_raw_info ||= access_token.get("#{uri.path}/v1/userinfo").parsed || {}
      rescue ::Errno::ETIMEDOUT
        raise ::Timeout::Error
      end

      def request_phase
        super
      end

      def callback_phase
        super
      end

      def callback_url
        options[:redirect_uri] || (full_host + script_name + callback_path)
      end

      def validated_token(token)
        JWT.decode(token,
                   nil,
                   false,
                   verify_iss:        true,
                   iss:               options[:issuer],
                   verify_aud:        true,
                   aud:               options[:audience],
                   verify_sub:        true,
                   verify_expiration: true,
                   verify_not_before: true,
                   verify_iat:        true,
                   verify_jti:        false,
                   leeway:            options[:jwt_leeway]
                   ).first
      end
    end
  end
end
