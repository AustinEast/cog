import cog.IComponent;
import cog.Components;
import cog.System;
import cog.Engine;
import cog.Node;

// Creating Component classes is as simple as implementing the `IComponent` interface.
// When the interface is implemented, the required Component fields are all added automatically.

@:structInit
class Position implements IComponent {
  public var x:Float = 0;
  public var y:Float = 0;
}

@:structInit
class Velocity implements IComponent {
  public var x:Float = 0;
  public var y:Float = 0;
}

// Plug the `Components` class into your own `Entity` class
class Entity {
  public var components:Components;
  public var name:String = '';

  public function new() {
    components = new Components();

    // Assign the Entity field on the Components instance
    // This is only available by using the integration build macro, detailed here: https://github.com/AustinEast/cog#integration
    components.entity = this;

    // Create the Position & Velocity Components, then add them to the Entity's Components instance
    var position:Position = {};
    var velocity:Velocity = {};
    components.add(position);
    components.add(velocity);
  }
}

// Create a System to randomly move Entities
class MovementSystem extends System {
  // Using the `@:nodes` metadata, create a collection of Nodes.
  // The Nodes class automatically tracks any `Components` object that has the Position and Velocity components,
  // and will create a `Node` object for each one
  @:nodes var nodes:Node<Position, Velocity>;

  // This method is called when a System is added to the Cog Engine
  // Override this to apply any needed initialization logic to your Nodes
  override function added(engine:Engine) {
    super.added(engine);

    // Set a random velocity on each Node that already exists in the System
    for (node in nodes) {
      node.velocity.x = Math.random() * 200;
      node.velocity.y = Math.random() * 200;
    }

    // Subscribe to the Node list's `added` event to set a random velocity to each Node as it gets added to the System
    nodes.added.add(node -> {
      node.velocity.x = Math.random() * 200;
      node.velocity.y = Math.random() * 200;
    });
  }

  // This method is called when a System is removed from the Cog Engine
  // Override this to apply any needed disposal logic to your Nodes
  override function removed() {
    super.removed();
  }

  // This method is called every time the Cog Engine is stepped forward by the Game Loop
  override public function step(dt:Float) {
    super.step(dt);
    for (node in nodes) {
      // Increment each Node's Position by it's Velocity
      // Each Node holds reference to the `Components` object, along with a reference to each Component defined by the Nodes list
      node.position.x += node.velocity.x * dt;
      node.position.y += node.velocity.y * dt;
    }
  }
}

// Create a System to "Render" the entities
class RenderSystem extends System {
  @:nodes var nodes:Node<Position>;

  override function step(dt:Float) {
    super.step(dt);

    // Log the Entities' Positions
    for (node in nodes) {
      trace('${node.entity.name} is at position (${node.position.x}, ${node.position.y})');
    }
    trace('---------- End Frame ------------');
  }
}

class Main {
  static function main() {
    // Create an Array to hold the Game's Entities
    var entities = [];

    // Create the Cog Engine
    var engine = new Engine();

    // Define a method to remove Entities from the Game
    inline function remove_entity(entity:Entity) {
      // Remove the Entity from the Game's Entity List
      entities.remove(entity);
      // Remove the Entity's `Components` from the Cog Engine
      engine.remove_components(entity.components);
    }

    // Define a method to add Entities to the Game
    inline function add_entity(entity:Entity) {
      // Remove the Entity from the Game first, to make sure we arent adding it twice
      remove_entity(entity);
      // Add the Entity to the Game's Entity List
      entities.push(entity);
      // Add the Entity's `Components` to the Cog Engine
      engine.add_components(entity.components);
    }

    // Add some Entities in random spots
    for (i in 0...10) {
      var entity = new Entity();
      entity.name = 'Entity ${i + 1}';
      var position = entity.components.get(Position);
      if (position != null) {
        position.x = Math.random() * 1000;
        position.y = Math.random() * 1000;
      }
      add_entity(entity);
    }

    // Add the Movement and Render Systems to the Cog Engine
    engine.add_system(new MovementSystem());
    engine.add_system(new RenderSystem());

    // Simulate a Game Loop
    new haxe.Timer(16).run = () -> {
      // Update the Cog Engine.
      engine.step(16 / 1000);
    }
  }
}
