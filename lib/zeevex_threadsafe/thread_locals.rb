#
# Usage:
#    class Foo
#      include ThreadLocals
#      thread_local :instance_var_name, :instance_var_name2 # , ...
#      cthread_local :class_var_name, :class_var_name2 # , ...
#    end
#
#    Foo.class_var_name = "thread specific value on class"
#    Foo.new.instance_var_name = "thread specific value on instance"
#
# A hash of options which may be passed in to control the visibility
# (public, private, protected) and default value of the variable.
#
#     class Foo
#         thread_local :example, :visibility => :protected, :default => 42
#     end
#     obj = Foo.new
#     obj.example => 42
#     obj.example = "non-default value"
#     obj.example  #  => "non-default-value"
#
#
module ZeevexThreadsafe::ThreadLocals
  def self.included(klass)
    klass.extend ClassMethods
    klass.send :include, InstanceMethods
  end

  module InstanceMethods
    private

    # remove the thread local maps for threads that are no longer active.
    # likely to be painful if many threads are running.
    #
    # must be called manually; otherwise this object may accumulate lots of garbage
    # if it is used from many different threads.
    def _thread_local_clean
      ids = Thread.list.map &:object_id
      (@_thread_local_threads.keys - ids).each { |key| @_thread_local_threads.delete(key) }
    end
  end

  module ClassMethods
    def thread_local(*args, &block)
      UtilityMethods.define_thread_local_accessors(self, args, block)
    end

    def cthread_local(*args, &block)
      UtilityMethods.define_thread_local_accessors(self.class, args, block)
    end
  end

  module UtilityMethods

    def self.thread_local_hash(base, autocreate = false)
      base.instance_eval do
        if autocreate
          @_thread_local_threads ||= {}
          @_thread_local_threads[Thread.current.object_id] ||= {}
        else
          @_thread_local_threads ? @_thread_local_threads[Thread.current.object_id] : nil
        end
      end
    end

    def self.define_thread_local_accessors(base, args, block = nil)
      options = args[-1].instance_of?(Hash) ? args.pop : {}
      args.each do |name|
        key = name.to_sym
        base.class_eval do
          define_method name.to_sym do
            hash = ZeevexThreadsafe::ThreadLocals::UtilityMethods.thread_local_hash(self)
            return hash[key] if hash && hash.key?(key)
            return block.call(self, key) if block
            return options[:default]
          end

          define_method (name.to_s + "=").to_sym do |value|
            ZeevexThreadsafe::ThreadLocals::UtilityMethods.thread_local_hash(self, true)[key] = value
          end

          if options[:visibility]
            send options[:visibility], name.to_sym, (name.to_s + "=").to_sym
          end
        end
      end
    end
  end
end
