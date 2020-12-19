package cog;

@:autoBuild(cog.Macros.build_component())
interface IComponent {
  /**
   * The Component's Class name, represented as either a String or as a Type.
   *
   * Example:
   * ```haxe
   * var myComponent = new MyComponent();
   * trace(myComponent.component_type == MyComponent); // true
   * trace(myComponent.component_type == "MyComponent"); // also true
   * ```
   */
  public var component_type(get, never):ComponentType;
  /**
   * The `Components` object that currently owns this Component.
   */
  public var owner(default, null):Components;
  /**
   * Optional callback method that gets called when this Component is added to a `Components` object.
   */
  public var owner_added:Components->Void;
  /**
   * Optional callback method that gets called when this Component is removed from a `Components` object.
   */
  public var owner_removed:Void->Void;
  /**
   * Removes this Component's owner object, if it has one.
   */
  public function remove_owner():Void;
}

@:forward(split)
abstract ComponentType(String) {
  inline function new(value:String) this = value;

  @:from
  public static inline function ofClass(value:Class<IComponent>):ComponentType return new ComponentType(Type.getClassName(value));

  @:from
  public static inline function ofInstance(value:IComponent):ComponentType return ofClass(Type.getClass(value));

  @:to
  public inline function toClass():Class<IComponent> return cast Type.resolveClass(this);

  @:to
  public inline function toString():String return this;
}
