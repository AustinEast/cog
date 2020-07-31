import cog.Components;
import cog.System;
import cog.Component;
import cog.Engine;
import cog.Node;
import component.Position;

// Plug the `Components` class into your own `Entity` class!
class Entity {
  public var components:Components;
  public var name:String = '';
  public var position:Position;

  public function new() {
    components = new Components();

    // Assign the Entity field on the Components instance
    // This is only available by using the integration build macro, detailed here: https://github.com/AustinEast/cog#integration
    components.entity = this;

    // Create and add the Position Component to the Entity
    position = new Position();
    components.add(position);
  }
}

// Create a Basic System
class MovementSystem extends System {
  @:nodes var nodes:Node<Position>;

  override public function step(dt:Float) {
    for (node in nodes) {
      node.position.x += 10 * dt;
      node.position.y += 10 * dt;
    }
  }
}

class Main {
  static function main() {
    // Create an Array to hold the Entities
    var entities = [];
    // Create the Cog Engine
    var engine = new Engine();

    // Define a method to remove Entities from the Game
    inline function remove_entity(entity:Entity) {
      entities.remove(entity);
      engine.remove_components(entity.components);
    }

    // Define a method to add Entities from the Game
    inline function add_entity(entity:Entity) {
      remove_entity(entity);
      entities.push(entity);
      engine.add_components(entity.components);
    }

    // Add some Entities in random spots
    for (i in 0...10) {
      var entity = new Entity();
      entity.name = 'Entity ${i + 1}';
      entity.position.x = Math.random() * 1000;
      entity.position.y = Math.random() * 1000;
      add_entity(entity);
    }

    // Add the Movement System
    engine.add_system(new MovementSystem());

    // Simulate a Game Loop
    new haxe.Timer(16).run = () -> {
      // Update the Cog Engine
      engine.step(16 / 1000);

      // Log our Entities Positions
      for (entity in entities) {
        trace('${entity.name} is a position (${entity.position.x}, ${entity.position.y})');
      }

      trace('---------- End Frame ------------');
    }
  }
}
