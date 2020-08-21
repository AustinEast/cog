package cog;

class Engine {
  public var active:Bool = true;
  public var systems:Array<System> = [];
  public var components:Array<Components> = [];
  public var components_added:Signal<Components> = new Signal<Components>();
  public var components_removed:Signal<Components> = new Signal<Components>();

  public function new() {}

  public function step(dt:Float) {
    if (active) for (system in systems) system.step(dt);
  }

  public function add_system(system:System) {
    if (!systems.contains(system)) {
      systems.push(system);
      system.added(this);
    }
  }

  public function remove_system(system:System) {
    if (systems.remove(system)) {
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
}
