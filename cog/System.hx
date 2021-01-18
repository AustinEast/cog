package cog;

@:autoBuild(cog.Macros.build_system())
class System {
  public var active(default, set):Bool = true;

  public var time_scale:Float = 1;

  public var fixed:Bool = false;

  public var fixed_framerate(default, set):Float = 60;

  @:allow(cog.Engine)
  var engine:Engine;

  var fixed_accumulator:Float = 0;

  var fixed_dt:Float;

  public function new() {}
  /**
   * This method is called every time this System's Engine is stepped forward. Override this to apply any logic that should run every frame.
   * @param dt
   */
  public function step(dt:Float) {}
  /**
   * This method is called when a System is added to the Cog Engine. Override this to apply any needed initialization logic for the System.
   * @param engine
   */
  public function added(engine:Engine) {
    this.engine = engine;
    add_nodes();
  }
  /**
   * This method is called when a System is removed from the Cog Engine. Override this to apply any needed disposal logic for the System.
   */
  public function removed() {
    if (engine != null) engine.remove_system(this);
    remove_nodes();
  }

  @:allow(cog.Engine)
  @:noCompletion
  function try_step(dt:Float) {
    if (!active) return;
    if (fixed) {
      fixed_accumulator += dt;
      while (fixed_accumulator > fixed_dt) {
        fixed_accumulator -= fixed_dt;
        step(fixed_dt * time_scale);
      }
    }
    else step(dt * time_scale);
  }

  @:noCompletion
  function add_nodes() {}

  @:noCompletion
  function remove_nodes() {}

  function set_fixed_framerate(v:Float) {
    fixed_framerate = Math.max(v, 0);
    fixed_dt = 1 / fixed_framerate;
    return fixed_framerate;
  }

  function set_active(v:Bool) {
    return active = v;
  }
}
