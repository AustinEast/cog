# cog
A Macro powered B.Y.O.E. (Bring Your Own Entity!) ECS Framework written in Haxe.

<!-- [![Build Status](https://travis-ci.org/AustinEast/cog.svg?branch=master)](https://travis-ci.org/AustinEast/cog) -->

ECS concepts & implementation inspired by [exp-ecs](https://github.com/kevinresol/exp-ecs).

<!-- ## Features -->

<!-- ## Getting Started -->

## Usage

<!-- ### Concepts

#### Engine

#### Component

#### Components

#### System

#### Node

#### Nodes -->

### Integration

A build macro is available to add custom fields to the `Components` class, such as an `Entity` class:

in build.hxml:
```hxml
--macro cog.Macros.add_data("entity", "some.package.Entity")
```

in Main.hx
```haxe
var components = new cog.Components();
components.entity = new some.package.Entity();
```

## Example

```haxe
import cog.Components;
import cog.System;
import cog.Engine;
import cog.Node;
import component.Position;
import component.Velocity;

// Plug the `Components` class into your own `Entity` class!
class Entity {
  public var components:Components;
  public var name:String = '';
  public var position:Position;
  public var velocity:Velocity;

  public function new() {
    components = new Components();

    // Assign the Entity field on the Components instance
    // This is only available by using the integration build macro, detailed here: https://github.com/AustinEast/cog#integration
    components.entity = this;

    // Create and add the Position & Velocity Components to the Entity
    position = new Position();
    velocity = new Velocity();
    components.add(position);
    components.add(velocity);
  }
}

// Create a Basic System
class MovementSystem extends System {

  // Using the `@:nodes` metadata, create a collection of Nodes.
  // The Nodes class automatically tracks any `Components` object that has the Position and Velocity components,
  // and will create a `Node` object for each one
  @:nodes var nodes:Node<Position,Velocity>;

  // This method is called when a System is added to the Cog Engine
  override function added(engine:Engine) {
    super.added(engine);

    // Subscribe to the Node list's `added` event to set a random velocity to each Node as it gets added to the System
    nodes.added.add(node -> {
      node.velocity.x = Math.random() * 10;
      node.velocity.y = Math.random() * 10;
    });
  }

  // This method is called every time the Cog Engine is stepped forward by the Game Loop
  override public function step(dt:Float) {
    for (node in nodes) {
      node.position.x += node.velocity.x;
      node.position.y += node.velocity.y;
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

    // Define a method to add Entities to the Game
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

      // Log the Entities' Positions
      for (entity in entities) {
        trace('${entity.name} is a position (${entity.position.x}, ${entity.position.y})');
      }
      trace('---------- End Frame ------------');
    }
  }
}

```
