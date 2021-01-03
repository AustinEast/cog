package cog;

import cog.Signal;

@:structInit
class NodeListeners {
  var added:Listener<IComponent->Void>;
  var removed:Listener<IComponent->Void>;

  public function dispose() {
    added.dispose();
    removed.dispose();
  }
}

class Nodes<T:Node.NodeBase> {
  public var added:Signal<T>;
  public var removed:Signal<T>;

  var engine:Engine;
  var factory:Components->T;
  var filter:Components->Bool;
  var track_adds:Listener<Components->Void>;
  var track_removes:Listener<Components->Void>;
  var components_index:Array<Int>;
  var members:Array<T>;
  var listeners:Map<Components, NodeListeners>;

  public function new(engine:Engine, factory:Components->T, filter:Components->Bool) {
    this.engine = engine;
    this.factory = factory;
    this.filter = filter;
    components_index = [];
    members = [];
    listeners = [];

    added = new Signal<T>();
    removed = new Signal<T>();

    for (components in engine.components) {
      track(components);
      if (filter(components)) add(components);
    }

    // Listen for any new Components objects being added to the Engine, then start tracking their Component changes
    track_adds = engine.components_added.add(components -> track(components));

    // Listen for any Components objects getting removed from the Engine, then stop tracking their Component changes
    track_removes = engine.components_removed.add(components -> untrack(components));
  }

  function add(components:Components) {
    if (components_index.indexOf(components.id) == -1) {
      components_index.push(components.id);
      var node = factory(components);
      members.push(node);
      added.dispatch(node);
    }
  }

  function remove(components:Components) {
    var i = components_index.indexOf(components.id);
    if (i > -1) {
      removed.dispatch(members[i]);
      members[i].dispose();
      members.splice(i, 1);
      components_index.splice(i, 1);
    }
  }
  /**
   * Adds a Listener to track Component changes in the Components object.
   * When a Component is added or removed from the Components object, the listener will check if the Components object belongs in this Nodes list.
   * @param components
   */
  function track(components:Components) {
    if (listeners.exists(components)) return;
    listeners.set(components, {
      added: components.added.add(component -> if (filter(components)) add(components)),
      removed: components.added.add(component -> if (!filter(components)) remove(components))
    });

    // Immediately check if the Components object should be added to this Node list
    if (filter(components)) add(components);
  }
  /**
   * Stops tracking the changes in a Components object, disposing of the associated Listener.
   * @param components
   */
  function untrack(components:Components) {
    var listener = listeners.get(components);
    if (listener != null) listener.dispose();
    // Attempt to remove the Components object from this Nodes list
    remove(components);
  }

  public function dispose() {
    track_adds.dispose();
    track_adds = null;
    track_removes.dispose();
    track_removes = null;
    listeners.clear();
    components_index.resize(0);
    for (member in members) member.dispose();
    members.resize(0);
  }

  public inline function iterator() return members.iterator();

  function toString() {
    return 'Nodes (members: ${members.toString()})';
  }
}
