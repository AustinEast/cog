package cog;

class Component {
  public var type(get, never):ComponentType;
  public var components(default, null):Components;

  public function new() {}

  public function added(components:Components) {
    this.components = components;
  }

  public function removed() {
    components = null;
  }

  public function dispose() {
    if (components != null) components.remove(type);
  }

  inline function get_type():ComponentType return this;
}

@:forward(split)
abstract ComponentType(String) {
  inline function new(value:String) this = value;

  @:from
  public static inline function ofClass(value:Class<Component>):ComponentType return new ComponentType(Type.getClassName(value));

  @:from
  public static inline function ofInstance(value:Component):ComponentType return ofClass(Type.getClass(value));

  @:to
  public inline function toClass():Class<Component> return cast Type.resolveClass(this);

  @:to
  public inline function toString():String return this;
}
