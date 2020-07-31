package cog;

@:genericBuild(cog.Macros.build_node())
class Node<Rest> {}

class NodeBase {
  var name:String = 'NodeBase';

  public var components:Components;

  public function dispose() {
    components = null;
  }

  public function toString() {
    return '$name( $components )';
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
