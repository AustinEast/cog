package cog;

@:autoBuild(cog.Macros.build_system())
class System {
  var engine:Engine;

  public function new() {}

  public function step(dt:Float) {}

  public function added(engine:Engine) {
    this.engine = engine;
    add_nodes();
  }

  public function removed() {
    engine = null;
    remove_nodes();
  }

  function add_nodes() {}

  function remove_nodes() {}
}
