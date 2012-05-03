require_dependency "weakref"

module ZeevexThreadsafe
  module Rails
    class RequestGlobals
      class << self

        REQUEST_VARNAME = "_zx_rg_request"
        INSTANCE_VARNAME = "@_zx_request_globals"

        def request
          ref = Thread.current[REQUEST_VARNAME]
          ref && ref.class == WeakRef && ref.weakref_alive? ? ref.__getobj__ : nil
        end

        def request=(request)
          Thread.current[REQUEST_VARNAME] = (request ? WeakRef.new(request) : nil)
        end

        def [](name)
          hash[name]
        end

        def []=(name, val)
          hash(true)[name] = val
        end

        def reset
          hash && hash.clear
          Thread.current[REQUEST_VARNAME] = nil
        end


        def define_request_global_accessors(base, name, key = nil)
          key ||= name
          base.class_eval do
            define_method name do
              ZeevexThreadsafe::Rails::RequestGlobals[key]
            end

            define_method (name.to_s + "=").to_sym do |value|
              ZeevexThreadsafe::Rails::RequestGlobals[key] = value
            end
          end
        end

        protected

        def hash(strict = false)
          req = request
          unless req
            if strict
              raise "No current request scope for RequestGlobal"
            else
              return {}
            end
          end

          hash = req.instance_variable_get(INSTANCE_VARNAME)
          if !hash
            hash = {}
            req.instance_variable_set(INSTANCE_VARNAME, hash)
          end
          hash
        end

      end

      module Controller
        def self.included(klass)
          klass.class_eval do
            alias_method_chain :process, :request_globals
            protected :process_without_request_globals, :process_with_request_globals
          end
        end

        def process_with_request_globals(request, response, method = :perform_action, *arguments)
          ZeevexThreadsafe::Rails::RequestGlobals.request = request
          process_without_request_globals(request, response, method, *arguments)
        ensure
          ZeevexThreadsafe::Rails::RequestGlobals.reset
        end
      end

      module Accessors
        def self.included(klass)
          klass.extend ClassMethods
        end

        module ClassMethods
          def request_global_accessor(name)
            ZeevexThreadsafe::Rails::RequestGlobals.define_request_global_accessors(self.class, name)
          end
        end
      end

    end

  end
end
