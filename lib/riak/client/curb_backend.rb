# Copyright 2010 Sean Cribbs, Sonian Inc., and Basho Technologies, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
require 'riak'

module Riak
  class Client
    # An HTTP backend for Riak::Client that uses the 'curb' library/gem.
    # If the 'curb' library is present, this backend will be preferred to
    # the backend based on Net::HTTP.
    # Conforms to the Riak::Client::HTTPBackend interface.
    class CurbBackend < HTTPBackend
      # @private
      def initialize(client)
        super
        @curl = Curl::Easy.new
        @curl.follow_location = false
        @curl.on_header do |header_line|
          @response_headers.parse(header_line)
          header_line.size
        end
      end

      private
      def perform(method, uri, headers, expect, data=nil)
        # Setup
        @curl.headers = headers
        @curl.url = uri.to_s
        @response_headers = Riak::Util::Headers.new
        @curl.on_body {|chunk| yield chunk; chunk.size } if block_given?

        # Perform
        case method
        when :put, :post
          @curl.send("http_#{method}", data)
        else
          @curl.send("http_#{method}")
        end

        # Verify
        if valid_response?(expect, @curl.response_code)
          result = { :headers => @response_headers.to_hash, :code => @curl.response_code.to_i }
          if return_body?(method, @curl.response_code, block_given?)
            result[:body] = @curl.body_str
          end
          result
        else
          raise FailedRequest.new(method, expect, @curl.response_code, @response_headers.to_hash, @curl.body_str)
        end
      end
    end
  end
end
