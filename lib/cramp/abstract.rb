require 'active_support/core_ext/hash/keys'

module Cramp
  class Abstract
    include Callbacks
    include FiberPool

    class_inheritable_accessor :transport
    self.transport = :regular

    class << self
      def call(env)
        controller = new(env).process
      end
    end

    def initialize(env)
      @env = env
      @finished = false
    end

    def process
      EM.next_tick { before_start }
      throw :async
    end

    protected

    def continue
      init_async_body

      status, headers = respond_with
      send_initial_response(status, headers, @body)

      EM.next_tick { on_start }
    end

    def respond_with
      [200, {'Content-Type' => 'text/html'}]
    end

    def init_async_body
      @body = Body.new

      if self.class.on_finish_callbacks.any?
        @body.callback { on_finish }
        @body.errback { on_finish }
      end
    end

    def finished?
      !!@finished
    end

    def finish
      @finished = true
      @body.succeed
    end

    def send_initial_response(response_status, response_headers, response_body)
      send_response(response_status, response_headers, response_body)
    end

    def halt(status, headers = {}, halt_body = '')
      send_response(status, headers, halt_body)
    end

    def send_response(response_status, response_headers, response_body)
      @env['async.callback'].call [response_status, response_headers, response_body]
    end

    def request
      @request ||= Rack::Request.new(@env)
    end

    def params
      @params ||= request.params.update(route_params).symbolize_keys
    end

    def route_params
      @env['router.params'] || @env['usher.params']
    end
  end
end
