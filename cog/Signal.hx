package cog;

import haxe.Constraints.Function;
/**
 * Signal implementation based on: https://gist.github.com/nadako/b086569b9fffb759a1b5
**/
@:genericBuild(cog.Macros.build_signal())
class Signal<Rest> {}

class SignalBase<T:Function> {
  var head:Listener<T>;
  var tail:Listener<T>;
  var toAddHead:Listener<T>;
  var toAddTail:Listener<T>;
  var dispatching:Bool = false;

  public function new() {}

  public function add(listener:T, once = false):Listener<T> {
    var listner = new Listener(this, listener, once);
    if (dispatching) {
      if (toAddHead == null) {
        toAddHead = toAddTail = listner;
      }
      else {
        toAddTail.next = listner;
        listner.previous = toAddTail;
        toAddTail = listner;
      }
    }
    else {
      if (head == null) {
        head = tail = listner;
      }
      else {
        tail.next = listner;
        listner.previous = tail;
        tail = listner;
      }
    }
    return listner;
  }

  public function remove(listener:Listener<T>):Void {
    if (head == listener) head = head.next;
    if (tail == listener) tail = tail.previous;
    if (toAddHead == listener) toAddHead = toAddHead.next;
    if (toAddTail == listener) toAddTail = toAddTail.previous;
    if (listener.previous != null) listener.previous.next = listener.next;
    if (listener.next != null) listener.next.previous = listener.previous;
  }

  inline function start_dispatch():Void {
    dispatching = true;
  }

  function end_dispatch():Void {
    dispatching = false;
    if (toAddHead != null) {
      if (head == null) {
        head = toAddHead;
        tail = toAddTail;
      }
      else {
        tail.next = toAddHead;
        toAddHead.previous = tail;
        tail = toAddTail;
      }
      toAddHead = toAddTail = null;
    }
  }
}

@:allow(cog.SignalBase)
@:access(cog.SignalBase)
class Listener<T:Function> {
  var signal:SignalBase<T>;
  var listener:T;
  var once:Bool;

  var previous:Listener<T>;
  var next:Listener<T>;

  function new(signal:SignalBase<T>, listener:T, once:Bool) {
    this.signal = signal;
    this.listener = listener;
    this.once = once;
  }

  public function dispose():Void {
    if (signal != null) {
      signal.remove(this);
      signal = null;
    }
  }
}
