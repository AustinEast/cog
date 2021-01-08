package cog;

import cog.IComponent;

@:build(cog.Macros.build_components())
class Components {
  static var ids:UInt = 0;
  /**
   * Unique id of the Components container.
   */
  public final id:UInt = ids++;

  public var active:Bool = true;
  public var added:Signal<IComponent> = new Signal<IComponent>();
  public var removed:Signal<IComponent> = new Signal<IComponent>();

  var members:Map<ComponentType, IComponent> = [];

  public function new() {}

  public function add(component:IComponent, overwrite:Bool = false):IComponent {
    if (overwrite) remove(component.component_type);
    else if (members.exists(component.component_type)) {
      trace('Component of type "${component.component_type}" already attached to Components #${id})');
      return component;
    }

    members.set(component.component_type, component);
    @:privateAccess
    component.owner = this;
    if (component.owner_added != null) component.owner_added(this);
    added.dispatch(component);
    return component;
  }

  public function remove(type:ComponentType):Null<IComponent> {
    var component = get(type);
    if (component != null) {
      members.remove(component.component_type);
      @:privateAccess
      component.owner = null;
      if (component.owner_removed != null) component.owner_removed();
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

  public inline function get<T:IComponent>(type:Class<T>):Null<T> return cast members.get((cast type : Class<IComponent>));

  public function dispose() {
    active = false;
    if (members != null) for (member in members) member.remove_owner();
    members = null;
  }

  public function toString() {
    return 'Components #$id';
  }
}
