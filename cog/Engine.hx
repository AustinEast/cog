package cog;

class Engine {
  public var active:Bool = true;
  public var systems:Map<Int, Array<System>> = [];
  public var components:Array<Components> = [];
  public var components_added:Signal<Components> = new Signal<Components>();
  public var components_removed:Signal<Components> = new Signal<Components>();

  // TODO cache and reuse "Nodes" between systems
  // var nodes_cache:Map<NodeType, Nodes<Dynamic>>;

  public function new() {}

  public function step(dt:Float, group:Int = 0) {
    if (active && systems.exists(group)) for (system in systems[group]) system.try_step(dt);
  }

  public function add_system(system:System, group:Int = 0) {
    if (systems[group] == null) systems[group] = [];
    if (!systems[group].contains(system)) {
      systems[group].push(system);
      system.added(this);
    }
  }

  public function remove_system(system:System, group:Int = 0) {
    if (systems[group] == null) return;
    if (systems[group].remove(system)) {
      system.removed();
    }
  }

  public function add_components(components:Components) {
    remove_components(components);
    this.components.push(components);
    components_added.dispatch(components);
  }

  public function remove_components(components:Components) {
    if (this.components.remove(components)) components_removed.dispatch(components);
  }

  public function dispose() {
    for (c in components) remove_components(c);
    components = null;

    for (key => arr in systems) for (i in 0...arr.length) remove_system(arr[i], key);
    systems = null;

    components_added = null;
    components_removed = null;
  }
}
