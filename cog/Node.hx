package cog;

@:genericBuild(cog.Macros.build_node())
class Node<Rest> {}

class NodeBase {
  var name:String = 'NodeBase';
  /**
   * The `Components` object that owns this Node instance.
   */
  public var owner:Components;

  public function dispose() {
    owner = null;
  }

  public function toString() {
    return '$name( $owner )';
  }
}

abstract NodeType(String) to String {
  inline function new(v:String)
    this = v;

  @:from
  public static inline function ofClass(v:Class<NodeBase>):NodeType
    return new NodeType(Type.getClassName(v));

  @:from
  public static inline function ofInstance(v:NodeBase):NodeType
    return ofClass(Type.getClass(v));

  @:to
  public inline function toClass():Class<NodeBase>
    return cast Type.resolveClass(this);
}
