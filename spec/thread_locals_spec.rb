# -*- coding: utf-8 -*-
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'zeevex_threadsafe/thread_locals'

class ThreadLocalTestClass
  include ZeevexThreadsafe::ThreadLocals
  thread_local(:block1, :block2) { |obj,key| "DEFAULT FOR #{obj.class}.#{key.to_s}" }
  thread_local :plain
  thread_local :mult1, :mult2
  thread_local :default_var, :default => 100
  thread_local :protected_var, :default => 200, :visibility => :protected
  thread_local :private_var, :default => 200, :visibility => :private
  thread_local :public_var, :default => 200, :visibility => :public

  private

  thread_local :contextually_private_var

  public

  thread_local :contextually_public_var
end

module ClassDuping
  def class_name
    @@class_name || self.class.to_s
  end

  def class_name=(name)
    @@class_name = name
  end

  def dupe_for_testing(name = self.name)
    self.dup.tap do |clazz|
      clazz.class_name = name
    end
  end
end

class ThreadLocalClassLevel
  include ZeevexThreadsafe::ThreadLocals
  extend ClassDuping
  cthread_local(:block1, :block2) { |obj,key| "DEFAULT FOR #{obj.class_name}.#{key.to_s}" }
  cthread_local :plain
  cthread_local :mult1, :mult2
  cthread_local :default_var, :default => 100
  cthread_local :protected_var, :default => 200, :visibility => :protected
  cthread_local :private_var, :default => 200, :visibility => :private
  cthread_local :public_var, :default => 200, :visibility => :public

  private

  cthread_local :contextually_private_var

  public

  cthread_local :contextually_public_var
end

class ThreadLocalClassLevel2
  include ZeevexThreadsafe::ThreadLocals
  extend ClassDuping

  cthread_local :plain
end


describe ZeevexThreadsafe::ThreadLocals do

  context "class inclusion" do
    it "should not add class methods to a class unless included" do
      Object.should_not respond_to(:thread_local)
      Object.should_not respond_to(:cthread_local)
    end

    it "should add class methods to a class when included" do
      ThreadLocalTestClass.should respond_to(:thread_local)
      ThreadLocalTestClass.should respond_to(:cthread_local)
    end
  end


  context "instance thread locals" do
    let :instance do
      ThreadLocalTestClass.new
    end
    let :instance2 do
      ThreadLocalTestClass.new
    end
    subject { instance }
    context "method definition" do

      [:block1, :block2, :plain, :mult1, :mult2, :block1, :default_var,
       :protected_var, :public_var, :contextually_private_var, :contextually_public_var].each do |key|
        it "should have defined reader for #{key}" do
          instance.should respond_to(key)
        end

        it "should have defined writer for #{key}" do
          instance.should respond_to((key.to_s + "=").to_sym)
        end
      end

      [:private_var].each do |key|
        it "should have defined reader for #{key}" do
          instance.private_methods.should include(key.to_s)
        end

        it "should have defined writer for #{key}" do
          instance.private_methods.should include(key.to_s + "=")
        end
      end
    end

    context "default value" do
      [:plain, :mult1, :mult2,
       :contextually_private_var, :contextually_public_var].each do |key|
        it "should returns nil unless configured otherwise" do
          instance.send(key).should be_nil
        end
      end

      it "should return constant value if :default option provided" do
        instance.default_var.should == 100
      end

      it "should return computed value if :block option provided" do
        instance.block1.should == "DEFAULT FOR ThreadLocalTestClass.block1"
      end
    end

    context "when setting" do
      it "should return the newly set value after being set" do
        instance.block1 = "BLOCK!"
        instance.block1.should == "BLOCK!"
      end

      it "should keep values separately for two instances" do
        instance.block1 = "INSTANCE1 VALUE"
        instance2.block1 = "INSTANCE2 VALUE"
        instance.block1.should == "INSTANCE1 VALUE"
        instance2.block1.should == "INSTANCE2 VALUE"
      end
    end

    context "visibility" do
      it "should define methods as public by default" do
        instance.public_methods.should include("plain", "plain=", "mult1", "mult1=")
      end

      it "should define methods as protected when :visibility => :protected" do
        instance.protected_methods.should include("protected_var", "protected_var=")
      end

      it "should define methods as private when :visibility => :private" do
        instance.private_methods.should include("private_var", "private_var=")
      end

      it "should define methods as public when :visibility is not provided, even in a private context" do
        instance.public_methods.should include("contextually_private_var", "contextually_private_var=")
      end
    end

    context "thread locality" do
      it "should return the same value in the same thread when called consecutively" do
        instance.mult1 = "barbar"
        instance.mult1.should == "barbar"
        instance.mult1.should == "barbar"
      end

      it "should return the default value in a new thread" do
        instance.default_var = "FOO"
        instance.default_var.should == "FOO"
        Thread.new { @res = instance.default_var }.join
        @res.should == 100
      end

      it "should not affect the value in one thread when set in a different thread" do
        instance.default_var = "FOO"
        instance.default_var.should == "FOO"
        Thread.new { instance.default_var = 2500 }.join
        instance.default_var.should == "FOO"
      end
    end

    context "per thread book-keeping" do
      let :book do
        instance.instance_variable_get("@_thread_local_threads")
      end

      it "should have no book-keeping data when first created" do
        book.should == nil
      end

      it "should have no book-keeping data for default value access" do
        instance.block1
        book.should == nil
      end

      it "should have one thread's worth of book-keeping data when first variable is set" do
        instance.mult1 = 3000
        book.should be_instance_of(Hash)
        book.should have(1).item
      end

      it "should have two thread's worth of book-keeping data when variable is set in two threads" do
        instance.mult1 = 3000
        Thread.new { instance.mult1 = 4000 }.join
        book.should have(2).items
      end

      it "should have one thread's worth of data when var is set in two threads, one thread terminated, and then cleaned" do
        instance.mult1 = 3000
        Thread.new { instance.mult1 = 4000 }.join
        instance.send :_thread_local_clean
        book.should have(1).item
      end
    end

  end


  context "class-level thread locals" do

    context "instance thread locals" do
      let :instance do
        ThreadLocalClassLevel.dupe_for_testing
      end

      let :instance2 do
        ThreadLocalClassLevel2.dupe_for_testing
      end

      subject { instance }
      context "method definition" do

        [:block1, :block2, :plain, :mult1, :mult2, :block1, :default_var,
         :protected_var, :public_var, :contextually_private_var, :contextually_public_var].each do |key|
          it "should have defined reader for #{key}" do
            instance.should respond_to(key)
          end

          it "should have defined writer for #{key}" do
            instance.should respond_to((key.to_s + "=").to_sym)
          end
        end

        [:private_var].each do |key|
          it "should have defined reader for #{key}" do
            instance.private_methods.should include(key.to_s)
          end

          it "should have defined writer for #{key}" do
            instance.private_methods.should include(key.to_s + "=")
          end
        end
      end

      context "default value" do
        subject { instance }
        [:plain, :mult1, :mult2,
         :contextually_private_var, :contextually_public_var].each do |key|
          it "should return nil for #{key}, being configured without default" do
            instance.send(key).should be_nil
          end
        end

        it "should return constant value if :default option provided" do
          instance.default_var.should == 100
        end

        it "should return computed value if :block option provided" do
          instance.block1.should == "DEFAULT FOR ThreadLocalClassLevel.block1"
        end
      end

      context "when setting" do
        it "should return the newly set value after being set" do
          instance.block1 = "BLOCK!"
          instance.block1.should == "BLOCK!"
        end


        it "should keep values separately for two instances" do
          instance.plain = "INSTANCE1 VALUE"
          instance2.plain = "INSTANCE2 VALUE"
          instance.plain.should == "INSTANCE1 VALUE"
          instance2.plain.should == "INSTANCE2 VALUE"
        end
      end

      context "visibility" do
        it "should define methods as public by default" do
          instance.public_methods.should include("plain", "plain=", "mult1", "mult1=")
        end

        it "should define methods as protected when :visibility => :protected" do
          instance.protected_methods.should include("protected_var", "protected_var=")
        end

        it "should define methods as private when :visibility => :private" do
          instance.private_methods.should include("private_var", "private_var=")
        end

        it "should define methods as public when :visibility is not provided, even in a private context" do
          instance.public_methods.should include("contextually_private_var", "contextually_private_var=")
        end
      end

      context "thread locality" do
        it "should return the same value in the same thread when called consecutively" do
          instance.mult1 = "barbar"
          instance.mult1.should == "barbar"
          instance.mult1.should == "barbar"
        end

        it "should return the default value in a new thread" do
          instance.default_var = "FOO"
          instance.default_var.should == "FOO"
          Thread.new { @res = instance.default_var }.join
          @res.should == 100
        end

        it "should not affect the value in one thread when set in a different thread" do
          instance.default_var = "FOO"
          instance.default_var.should == "FOO"
          Thread.new { instance.default_var = 2500 }.join
          instance.default_var.should == "FOO"
        end
      end
    end
  end

  class DualThreadLocalTypes
    include ZeevexThreadsafe::ThreadLocals
    thread_local :foo
    cthread_local :foo
  end

  context "same named thread locals at class and instance level" do
    let :clazz do
      DualThreadLocalTypes
    end
    let :instance do
      DualThreadLocalTypes.new
    end
    it "should not set one when setting the other" do
      clazz.foo = "classvalue"
      instance.foo = "instancevalue"
      clazz.foo.should == "classvalue"
      instance.foo.should == "instancevalue"
    end
  end

  class MetaClassThreadLocals
    class << self
      include ZeevexThreadsafe::ThreadLocals
      thread_local :foo
    end
  end

  context "defining thread_local on metaclass of a class" do
    let :instance do
      MetaClassThreadLocals
    end
    subject { instance }
    it "should have a :foo method defined" do
      instance.should respond_to(:foo)
    end
  end
end
