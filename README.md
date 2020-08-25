<p align="center">
  <img src="https://raw.githubusercontent.com/AustinEast/cog/master/assets/logo.png">
</p>

# cog
A Macro powered B.Y.O.E. (Bring Your Own Entity!) ECS Framework written in Haxe.

[![Build Status](https://travis-ci.org/AustinEast/cog.svg?branch=master)](https://travis-ci.org/AustinEast/cog)

ECS concepts & implementation inspired by [exp-ecs](https://github.com/kevinresol/exp-ecs).

## Why?

As a big fan of the Macro approach and concepts in [exp-ecs](https://github.com/kevinresol/exp-ecs), I originally wrote `cog` as a piece of the [ghost framework](https://github.com/AustinEast/ghost) to provide that same kind of workflow. But as that project evolved and changed it's focus to 2D only, I found I wanted to be able to plug it's dead simple ECS implementation into _any_ kind of project, with no extra dependencies required. So I ripped the ECS out of the ghost framework, and `cog` was born!

<!-- ## Features -->

## Getting Started

Cog requires [Haxe 4](https://haxe.org/download/) to run.

Install the library from haxelib:
```
haxelib install cog
```
Alternatively the dev version of the library can be installed from github:
```
haxelib git cog https://github.com/AustinEast/cog.git
```

Then include the library in your project's `.hxml`:
```hxml
-lib cog
```
For OpenFL users, add this into your `Project.xml`:

```xml
<haxelib name="cog" />
```

For Kha users (who don't use haxelib), clone cog to the `Libraries` folder in your project root, and then add the following to your `khafile.js`:

```js
project.addLibrary('cog');
```


## Usage

### Concepts

#### Engine

The `Engine` is the entry point for Cog - it's main purpose is keeping track of `Components` and updating each `System`.

#### Component

A `Component` is an object that holds data that define an entity. Generally a component only holds variables, with little-to-no logic.

#### Components

A `Components` object is a container that holds `Component` instances. 
This class is meant to be integrated into your own project's base object class (ie Entity, GameObject, Sprite, etc). 

#### System

A `System` tracks collections of `Components` (as `Nodes`) for the purpose of performing logic on them. 

#### Node

A `Node` object keeps reference to a `Components` object and its relevant `Component` instances.

#### Nodes

A `Nodes` object tracks all the `Components` objects in the `Engine`, creating a `Node` for every `Components` object that contains all of it's required `Component` instances. `Nodes` objects are used by `System` objects to perform logic on `Components`.

### Integration

A build macro is available to add custom fields to the `Components` class, such as an `Entity` class:

in build.hxml:
```hxml
--macro cog.Macros.add_data("entity", "some.package.Entity")
```

in Main.hx:
```haxe
var components = new cog.Components();
components.entity = new some.package.Entity();
```

This will also add a reference to the custom field into every `Node` instance:
```haxe
class TestSystem extends System {
  @:nodes var nodes:Node<Position>;

  override function step(dt:Float) {
    super.step(dt);

    for (node in nodes) {
      // The `Entity` custom field can be accessed through the `Components` object
      trace('${node.components.entity.name}');

      // OR it can be accessed directly from the Node
      trace('${node.entity.name}');
    }
  }
}
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

// Create a System to randomly move Entities
class MovementSystem extends System {
  // Using the `@:nodes` metadata, create a collection of Nodes.
  // The Nodes class automatically tracks any `Components` object that has the Position and Velocity components,
  // and will create a `Node` object for each one
  @:nodes var nodes:Node<Position, Velocity>;

  // This method is called when a System is added to the Cog Engine
  override function added(engine:Engine) {
    super.added(engine);

    // Set a random velocity on each Node
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
    for (i in 0...1) {
      var entity = new Entity();
      entity.name = 'Entity ${i + 1}';
      entity.position.x = Math.random() * 1000;
      entity.position.y = Math.random() * 1000;
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
```

## Roadmap

* Source Documentation
* Fixed-Step Systems
* Improve Disposal
