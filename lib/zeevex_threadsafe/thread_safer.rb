require 'thread'

begin
  require 'active_support/core_ext'
rescue LoadError
  require 'zeevex_threadsafe/aliasing'
end

module ZeevexThreadsafe
  module ThreadSafer

    def self.included base
      base.extend ZeevexThreadsafe::ThreadSafer::ClassMethods
      base.class_eval do
        include ZeevexThreadsafe::ThreadSafer::InstanceMethods

        @delayed_thread_safe_methods = []

        if method_defined?(:method_added)
          class << self
            alias_method_chain :method_added, :thread_safe
          end
        else
          class << self
            alias_method :method_added, :method_added_with_thread_safe
          end
        end
      end
    end

    module ClassMethods
      def method_added_with_thread_safe(method)
        if !method.to_s.match(/_without_mutex$/) && @delayed_thread_safe_methods.include?(method)
          @delayed_thread_safe_methods.delete method
          make_thread_safe(method)
        end
        method_added_without_thread_safe(method) if method_defined?(:method_added_without_thread_safe)
      end

      def make_thread_safe *methods
        methods.each do |method|
          method = method.to_sym
          if method_defined?(method)
            make_thread_safe_now method
          else
            @delayed_thread_safe_methods << method
          end
        end
      end

      def make_thread_safe_now *methods
        methods.each do |method|
          old_name = method.to_sym
          new_name = (old_name.to_s + "_without_mutex").to_sym
          alias_method new_name, old_name
          myprox = lambda do |*args, &block|
            _ts_mutex.synchronize do
              @in_thread_safe_method = old_name
              res = __send__ new_name, *args, &block
              @in_thread_safe_method = nil
              res
            end
          end
          define_method old_name, myprox
        end
      end

    end

    module InstanceMethods
      def _ts_mutex
        @_ts_mutex ||= Mutex.new
      end
    end

  end
end

#
# class Foo
#   include ZeevexThreadsafe::ThreadSafer
#
#   class << self
#   include ZeevexThreadsafe::ThreadSafer
#   end
#   def foo_unsafe
#     puts "unsafe: #{@in_thread_safe_method}"
#   end
#
#   def foo_safe
#     puts "Safe: #{@in_thread_safe_method}"
#   end
#
#   make_thread_safe :foo_safe, :foo_safe_delayed, :hibbity, :hop
#
#   def foo_safe_delayed
#     puts "safe delayed: #{@in_thread_safe_method}"
#   end
#
#   class << self
#     def cmethod
#       puts "in cmethod: #{@in_thread_safe_method}"
#     end
#     make_thread_safe :cmethod
#   end
#
# end
#
# Foo.new.foo_unsafe
# Foo.new.foo_safe
# Foo.new.foo_safe_delayed
# Foo.cmethod
# Foo.class_eval do
#   puts "remaining delayed methods are #{@delayed_thread_safe_methods.inspect}"
# end
