require "cute"

require "./cuter/*"

module Cute

  # This should be kept in sync with Cute, plus:
  # * pass self to Signal_{{call.name.id}}.new()
  macro signal(call, async = false)
    class Signal_{{ call.name.id }} < ::Cute::Signal
      #include EventEmitter
      ::Cute::Signal.implementation({{ call }}, {{ async }})
    end

    @cute_signal_{{ call.name.id }} : Signal_{{ call.name.id }}?
    def {{ call.name.id }} : Signal_{{ call.name.id }}
      signal = @cute_signal_{{ call.name.id }}

      if signal.nil?
        signal = @cute_signal_{{ call.name.id }} = Signal_{{ call.name.id }}.new(self)
      end

      signal
    end
  end

  # Base class for `Cute.signal`
  abstract class Signal
    # Returns the name of the signal, if applicable.
    def name : String?
      nil
    end

    # Removes the handler with the handle *handler_hash*.
    def disconnect(handler_hash)
      @listeners.reject!{|handler| handler.hash == handler_hash}
    end

    # Removes all handlers
    def disconnect
      @listeners.clear
    end

    # Waits for the next event and returns the signal arguments.
    # See `samples/wait.cr` for a usage example.
    def wait
      channel, handle = new_channel
      result = channel.receive
      disconnect handle
      result
    end

    # Private-ish macro writing methods as required by `Signal` for a sub-class
    # of it.  `call` is expected to be a `CallNode`, and `async` if the signal
    # emission shall be delivered asynchronously, or right away.
    #
    # **Note**: You usually don't use this macro yourself.  See `Cute.signal`
    # instead.
    macro implementation(call, async)
      {% if call.args.empty? %}
        # NOTE: Nil -> Bool
        {% handler_type = "Proc(Bool)" %}
        {% channel_type = "Channel(Nil)" %}
      {% else %}
        # NOTE: Nil -> Bool
        {% handler_type = "Proc(#{ call.args.map(&.type).splat }, Bool)" %}
        {% if call.args.size == 1 %}
          {% channel_type = "Channel(#{ call.args[0].type })" %}
        {% else %}
          {% channel_type = "Channel(Tuple(#{ call.args.map(&.type).splat }))" %}
        {% end %}
      {% end %}

      @listeners : Array({{ handler_type.id }})

      getter parent : EventEmitter

      # NOTE: Overriden, added @parent and @listeners1
      def initialize(@parent)
        #@listeners1 = Array({{ handler_type.id }}).new
        @listeners = Array({{ handler_type.id }}).new
      end

      def name : String
        {{ call.name.stringify }}
      end

      # NOTE: Added emit of new_listener
      def on(&block : {{ handler_type.id }}) : ::Cute::ConnectionHandle
        @listeners << block
        bh = block.hash.to_u64
        if {{ call.name.stringify }} != "new_listener"
	  p = @parent
          if p
            p.new_listener.emit {{ call.name.stringify }}, bh
          end
        end
        bh
      end

      def on(sink : Cute::Sink(U)) forall U
        if sink.is_a?(Cute::Sink(Nil))
          on{ sink.notify(nil.as(U)) }
        else
          {% if call.args.empty? %}
            on{ sink.notify(nil.as(U)) }
          {% elsif call.args.size == 1 %}
            on{|arg| sink.notify(arg.as(U))}
          {% else %}
            on{|{{ call.args.map(&.var.id).splat }}| sink.notify({ {{ call.args.map(&.var.id).splat }} }.as(U))}
          {% end %}
        end
      end

      def new_channel : Tuple({{ channel_type.id }}, ::Cute::ConnectionHandle)
        ch = {{ channel_type.id }}.new

        handle = {% if call.args.empty? %}
          on{ ch.send(nil) }
        {% elsif call.args.size == 1 %}
          on{|arg| ch.send(arg)}
        {% else %}
          on{|{{ call.args.map(&.var.id).splat }}| ch.send({ {{ call.args.map(&.var.id).splat }} })}
        {% end %}

        { ch, handle }
      end

      # NOTE: Added return value
      def emit({{ call.args.splat }}) : Bool
        {% if async %}spawn do{% end %}
        ret = true
        @listeners.each do |handler|
          ret &&= handler.call({{ call.args.map(&.var.id).splat }})
        end
        #@listeners1.dup.each do |handler|
        #  disconnect handler.hash.to_u64
        #end
        ret
        {% if async %}end{% end %}
      end

      # NOTE: Equivalent of emit in Blessed
      def emit2({{ call.args.splat }}) : Bool
        @parent.event.emit name

        if name == "screen"
          return emit({{ call.args.map(&.var.id).splat }})
        end

        if emit({{ call.args.map(&.var.id).splat }}) == false
          return false
        end

	el= self # Here, el/self is signal
puts el.class
	# This loops over all object in the hierarchy
        while el= el.parent
puts el.class
          #if el.responds_to?(:element_{{call.name.id}})
          #  if el.element_{{ call.name.id }}.emit(self, {{ call.args.map(&.var.id).splat }}) == false
          #    return false
          #  end
          #end
        end

        true
      end
    end
  end
end

module EventEmitter
  @parent : EventEmitter?
  getter parent

  Cute.signal new_listener(type : String, hash : UInt64)
  Cute.signal remove_listener(type : String, hash : UInt64)
  Cute.signal event(type : String)

end
