require "./spec_helper"

class CuterTest
  include EventEmitter

  property events = 0
  property new_listeners = 0
  property remove_listeners = 0
  property clicks = 0

  Cute.signal clicked( x : Int64, y : String)
end

describe Cuter do
  it "can trigger signals" do
    t1= CuterTest.new
p t1.parent

    { t1.events, t1.new_listeners, t1.remove_listeners, t1.clicks }.should eq( {0,0,0,0})

    t1.clicked.on { true }
    t1.remove_listener.on { t1.remove_listeners+= 1; true }
    t1.event.on { t1.events+= 1; true }
    t1.new_listener.on { t1.new_listeners+= 1; true }

    { t1.events, t1.new_listeners, t1.remove_listeners, t1.clicks }.should eq( {0,0,0,0})

    t1.clicked.on { t1.clicks+= 1; true }

    { t1.events, t1.new_listeners, t1.remove_listeners, t1.clicks }.should eq( {0,1,0,0})

    t1.clicked.emit2( 1i64, "2")

    { t1.events, t1.new_listeners, t1.remove_listeners, t1.clicks }.should eq( {1,1,0,1})

  end
end
