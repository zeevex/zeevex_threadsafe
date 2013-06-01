require 'zeevex_proxy'
require 'thread'

#
# Wraps an object so that method calls to it via the proxy are synchronized.
#
# These are all equivalent:
#
#   ZeevexThreadsafe::Synchronized.new(orig_object)
#   ZeevexThreadsafe::Synchronized.wrap(orig_object)
#   ZeevexThreadsafe.synchronized orig_object
#
# Each style of invocation returns a new proxy object which wraps
# orig_object such that every method invocation *through the proxy*
# will be synchronized with a per-object Mutex.
#
# Each style also accepts an optional second argument which is a Mutex
# (or anything that duck-types with Mutex#synchronize).  This allows
# multiple objects to be synchronized on the same mutex.
#
# Note that internal method calls within the wrapped object are *not*
# synchronized. If any thread can access the wrapped object directly,
# then this class will not guarantee thread-safety.
#

module ZeevexThreadsafe
  class Synchronized < ZeevexProxy::Base
    def initialize(obj, mutex = Mutex.new)
      super
      @__synchronized_mutex = mutex
    end

    def method_missing(name, *args, &block)
      @__synchronized_mutex.synchronize do
        super
      end
    end

    #
    # Run a block within a synchronized block around this object's mutex
    #
    def synchronize(&block)
      @__synchronized_mutex.synchronize do
        yield
      end
    end

    def self.wrap(*args)
      Synchronized.new(*args)
    end
  end

  def self.synchronized(*args)
    ZeevexThreadsafe::Synchronized.wrap(*args)
  end
end


#
#
#
# See also https://github.com/ryanlecompte/synchronizable
#
