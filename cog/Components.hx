package cog;

import cog.Component;

@:build(cog.Macros.build_components())
class Components {
  static var ids:UInt = 0;
  /**
   * Unique id of the Components container.
   */
  public final id:UInt = ids++;

  public var active:Bool = true;
  public var added:Signal<Component> = new Signal<Component>();
  public var removed:Signal<Component> = new Signal<Component>();

  var members:Map<ComponentType, Component> = [];

  public function new() {}

  public function add(component:Component, overwrite:Bool = false):Component {
    if (overwrite) remove(component.type);
    else if (members.exists(component.type)) {
      trace('Component of type "${component.type}" already attached to Components #${id})');
      return component;
    }

    members.set(component.type, component);
    component.added(this);
    added.dispatch(component);
    return component;
  }

  public function remove(type:ComponentType):Null<Component> {
    var component = get(type);
    if (component != null) {
      members.remove(component.type);
      component.removed();
      removed.dispatch(component);
      return component;
    }
    return null;
  }

  public inline function has(type:ComponentType):Bool return members.exists(type);

  public function has_all(types:Array<ComponentType>):Bool {
    for (type in types) if (!has(type)) return false;
    return true;
  }

  public inline function get<T:Component>(type:Class<T>):Null<T> return cast members.get((cast type : Class<Component>));

  public function dispose() {
    active = false;
    if (members != null) for (member in members) member.dispose();
    members = null;
  }

  public function toString() {
    return 'Components #$id';
  }
}
