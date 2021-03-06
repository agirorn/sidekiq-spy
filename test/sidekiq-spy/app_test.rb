require_relative '../helper'

require_relative '../../lib/sidekiq-spy'


def start_and_stop_app(app)
  app_thread = Thread.new { app.start }
  
  sleep 1 # patience, patience; give app time to start
  
  app.stop
  
  app_thread.join(2)
  
  Thread.kill(app_thread)
end


describe SidekiqSpy::App do
  
  before do
    @screen = stub(
      :close     => nil,
      :refresh   => nil,
      :next_key  => nil,
      :missized? => nil
    )
    
    SidekiqSpy::Display::Screen.stubs(:new).returns(@screen)
    
    @app = SidekiqSpy::App.new
  end
  
  it "sets status not-running" do
    @app.running.must_equal false
  end
  
  it "sets status not-restarting" do
    @app.restarting.must_equal false
  end
  
  describe "#configure" do
    it "configures Sidekiq" do
      Sidekiq.expects(:configure_client)
      
      @app.configure {  }
    end
  end
  
  describe "configure block main" do
    before do
      @app.configure do |c|
        c.namespace = 'resque'
        c.interval  = 1
      end
      
      @config = @app.config
    end
    
    it "configures namespace" do
      @config.namespace.must_equal 'resque'
    end
    
    it "configures interval" do
      @config.interval.must_equal 1
    end
  end
  
  describe "configure block url" do
    before do
      @app.configure do |c|
        c.url = 'redis://da.example.com:237/42'
      end
      
      @config = @app.config
    end
    
    it "configures host" do
      @config.host.must_equal 'da.example.com'
    end
    
    it "configures port" do
      @config.port.must_equal 237
    end
    
    it "configures database" do
      @config.database.must_equal 42
    end
  end
  
  describe "configure block url-brief" do
    before do
      @app.configure do |c|
        c.url = 'redis://da.example.com'
      end
      
      @config = @app.config
    end
    
    it "configures host" do
      @config.host.must_equal 'da.example.com'
    end
    
    it "configures port" do
      @config.port.must_equal 6379
    end
    
    it "configures database" do
      @config.database.must_equal 0
    end
  end
  
  describe "configure block non-url" do
    before do
      @app.configure do |c|
        c.host      = 'da.example.com'
        c.port      = 237
        c.database  = 42
      end
      
      @config = @app.config
    end
    
    it "configures host" do
      @config.host.must_equal 'da.example.com'
    end
    
    it "configures port" do
      @config.port.must_equal 237
    end
    
    it "configures database" do
      @config.database.must_equal 42
    end
  end
  
  describe "#start" do
    before do
      @app.configure do |c|
        c.interval = 10
      end
    end
    
    it "sets status running within 1s" do
      thread_app = Thread.new { @app.start }
      
      sleep 1 # patience, patience; give app time to start
      
      @app.running.must_equal true
      
      Thread.kill(thread_app)
    end
    
    it "stops running within 1s" do
      thread_app = Thread.new { @app.start }
      
      sleep 1 # patience, patience; give app time to start
      
      @app.stop; t0 = Time.now
      
      thread_app.join(2)
      
      Thread.kill(thread_app)
      
      assert_operator (Time.now - t0), :<=, 1
    end
    
    it "calls #setup hook" do
      @app.expects(:setup)
      
      start_and_stop_app(@app)
    end
    
    it "calls #refresh on screen" do
      @screen.expects(:refresh)
      
      start_and_stop_app(@app)
    end
    
    it "calls #next_key on screen" do
      @screen.expects(:next_key).at_least_once
      
      start_and_stop_app(@app)
    end
    
    it "calls #cleanup hook" do
      @app.expects(:cleanup)
      
      start_and_stop_app(@app)
    end
  end
  
  describe "#stop" do
    before do
      @app.instance_variable_set(:@running, true)
    end
    
    it "sets status not-running" do
      @app.stop
      
      @app.running.must_equal false
    end
  end
  
  describe "#restart" do
    before do
      @app.instance_variable_set(:@restarting, false)
    end
    
    it "sets status restarting" do
      @app.restart
      
      @app.restarting.must_equal true
    end
  end
  
  describe "#do_command" do
    before do
      @app.instance_variable_set(:@running, true)
      @app.instance_variable_set(:@screen, @screen)
    end
    
    it "<q> sets status not-running" do
      @app.do_command('q')
      
      @app.running.must_equal false
    end
    
    it "<w> switches to Workers panel" do
      @screen.expects(:panel_main=).with(:workers)
      
      @app.do_command('w')
    end
    
    it "<u> switches to Queues panel" do
      @screen.expects(:panel_main=).with(:queues)
      
      @app.do_command('u')
    end
  end
  
end
