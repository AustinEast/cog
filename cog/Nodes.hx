package cog;

import cog.Signal;

@:structInit
class NodeListeners {
  var added:Listener<Component->Void>;
  var removed:Listener<Component->Void>;

  public function dispose() {
    added.dispose();
    removed.dispose();
  }
}

@:generic
class Nodes<T:Node.NodeBase> {
  public var added:Signal<T>;
  public var removed:Signal<T>;

  var engine:Engine;
  var factory:Components->T;
  var filter:Components->Bool;
  var track_adds:Listener<Components->Void>;
  var track_removes:Listener<Components->Void>;
  var components:Array<Int>;
  var members:Array<T>;
  var listeners:Map<Components, NodeListeners>;

  public function new(engine:Engine, factory:Components->T, filter:Components->Bool) {
    this.engine = engine;
    this.factory = factory;
    this.filter = filter;
    components = [];
    members = [];
    listeners = [];

    added = new Signal<T>();
    removed = new Signal<T>();

    for (components in engine.components) {
      track(components);
      if (filter(components)) add(components);
    }

    track_adds = engine.components_added.add(components -> {
      track(components);
      if (filter(components)) add(components);
    });
    track_removes = engine.components_removed.add(components -> {
      untrack(components);
      remove(components);
    });
  }

  function add(components:Components) {
    if (this.components.indexOf(components.id) == -1) {
      this.components.push(components.id);
      var node = factory(components);
      members.push(node);
      added.dispatch(node);
    }
  }

  function remove(components:Components) {
    var i = this.components.indexOf(components.id);
    if (i > -1) {
      removed.dispatch(members[i]);
      members[i].dispose();
      members.splice(i, 1);
      this.components.splice(i, 1);
    }
  }

  function track(components:Components) {
    if (listeners.exists(components)) return;
    listeners.set(components, {
      added: components.added.add(component -> if (filter(components)) add(components)),
      removed: components.added.add(component -> if (!filter(components)) remove(components))
    });
  }

  function untrack(components:Components) {
    var listener = listeners.get(components);
    if (listener != null) {
      listener.dispose();
      remove(components);
    }
  }

  public function dispose() {
    track_adds.dispose();
    track_adds = null;
    track_removes.dispose();
    track_removes = null;
    listeners.clear();
    components.resize(0);
    for (member in members) member.dispose();
    members.resize(0);
  }

  public inline function iterator() return members.iterator();

  function toString() {
    return 'Nodes (members: ${members.toString()})';
  }
}
