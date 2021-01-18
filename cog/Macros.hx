package cog;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

using haxe.macro.Tools;

class Macros {
  static var dataFields:Map<String, String> = [];
  /**
   * Build Macro to add extra fields to the Components class.
   *
   * Example: in build.hxml - `--macro cog.Macros.add_data("entity", "some.package.Entity")
   * @param name
   * @param type
   */
  public static function add_data(name:String, type:String) {
    dataFields[name] = type;
  }

  static function type_exists(typeName:String):Bool {
    try {
      if (Context.getType(typeName) != null) return true;
    } catch (error:String) {}

    return false;
  }

  static function is_subclass(is:ClassType, of:ClassType):Bool {
    if (is.superClass == null) return false;
    var pass = is.superClass.t.get().name == of.name;
    if (pass == false && is.superClass != null) return is_subclass(is.superClass.t.get(), of);
    return pass;
  }

  static function build_system():Array<Field> {
    var fields = Context.getBuildFields();
    var addNodesExpr:Array<Expr> = [];
    var removeNodesExpr:Array<Expr> = [];
    var newFields:Array<Field> = [];
    var pos = Context.currentPos();

    // Loop through each field
    for (field in fields) {
      // Look for fields with the @:nodes metadata
      if (field.meta != null) for (tag in field.meta) if (tag.name == ':nodes') {
        // Ensure the field is a Variable
        switch field.kind {
          case FVar(t, e):
            var fieldName = field.name;
            // Set the field type to `Nodes`
            field.kind = FieldType.FVar(macro:cog.Nodes<$t>, e);
            // Get the TypePath of the `Node` class
            var ct = t.toType().getClass();
            var typePath = {
              name: ct.name,
              pack: ct.pack
            }

            // Add the [field name]_added_listener and [field name]_removed_listener variable
            newFields.push({
              access: [APublic],
              name: '${fieldName}_added_listener',
              pos: pos,
              kind: FVar(macro:cog.Signal.Listener < $t -> Void >)
            });

            newFields.push({
              access: [APublic],
              name: '${fieldName}_removed_listener',
              pos: pos,
              kind: FVar(macro:cog.Signal.Listener < $t -> Void >)
            });

            // Add the [field name]_added and [field name]_removed methods
            newFields.push({
              access: [APublic],
              name: '${fieldName}_added',
              pos: pos,
              kind: FVar(macro:Null < $t -> Void >)
            });

            newFields.push({
              access: [APublic],
              name: '${fieldName}_removed',
              pos: pos,
              kind: FVar(macro:Null < $t -> Void >)
            });

            var fullNodeName = ct.pack.concat([ct.name]);
            // Make the expression to create the `Nodes` when the system is added
            addNodesExpr.push(macro {
              // Get the Nodes from the Engine's Nodes cache
              $i{fieldName} = engine.get_nodes($p{fullNodeName},
                () -> new cog.Nodes(engine, components -> new $typePath(components), (components) -> components.has_all($p{fullNodeName}.component_types)));

              // Add all existing nodes
              if ($i{'${fieldName}_added'} != null) for (node in $i{fieldName}) $i{'${fieldName}_added'}(node);

              // Add the nodes_added and nodes_removed listeners
              $i{'${fieldName}_added_listener'} = $i{fieldName}.added.add((node) -> if ($i{'${fieldName}_added'} != null) $i{'${fieldName}_added'}(node));
              $i{'${fieldName}_removed_listener'} = $i{fieldName}.removed.add((node) -> if ($i{'${fieldName}_removed'} != null)
                $i{'${fieldName}_removed'}(node));
            });
            // Make the expressions to destroy the `Nodes` when the system is removed
            removeNodesExpr.push(macro {
              if ($i{'${fieldName}_added_listener'} != null) $i{'${fieldName}_added_listener'}.dispose();
              if ($i{'${fieldName}_removed_listener'} != null) $i{'${fieldName}_removed_listener'}.dispose();
              if ($i{fieldName} != null && $i{'${fieldName}_removed'} != null) {
                for (node in $i{fieldName}) $i{'${fieldName}_removed'}(node);
              }
              $i{fieldName} = null;
            });
          default:
            throw('@:nodes metadata can only be used on a variable of `Node<T>` class');
        }
      }
    }

    // add expressions to create nodelists
    if (addNodesExpr.length > 0) newFields.push({
      access: [AOverride, AInline],
      name: 'add_nodes',
      pos: pos,
      kind: FFun({
        args: [],
        ret: macro:Void,
        expr: macro $b{addNodesExpr}
      })
    });

    // add expressions to remove nodelists
    if (removeNodesExpr.length > 0) newFields.push({
      access: [AOverride, AInline],
      name: 'remove_nodes',
      pos: pos,
      kind: FFun({
        args: [],
        ret: macro:Void,
        expr: macro $b{removeNodesExpr}
      })
    });

    return fields.concat(newFields);
  }

  static function build_node():ComplexType {
    return switch (Context.getLocalType()) {
      case TInst(_.get() => {name: "Node"}, params):
        build_node_class(params);
      default:
        throw false;
    }
  }
  /**
   * Signal implementation based on: https://gist.github.com/nadako/b086569b9fffb759a1b5
  **/
  static function build_signal():ComplexType {
    return switch (Context.getLocalType()) {
      case TInst(_.get() => {name: "Signal"}, params):
        build_signal_class(params);
      default:
        throw false;
    }
  }

  static function build_components() {
    if (Lambda.count(dataFields) == 0) return null;
    var fields = Context.getBuildFields();
    var pos = Context.currentPos();
    for (kv in dataFields.keyValueIterator()) {
      fields.push({
        name: kv.key,
        access: [Access.APublic],
        kind: FieldType.FVar(Context.toComplexType(Context.getType(kv.value))),
        pos: pos
      });
    }
    return fields;
  }

  static function build_component() {
    // Check if this Class has already added the required `IComponent` fields in one of it's parent Classes. Exit early if so.
    var sc = Context.getLocalClass().get().superClass;
    while (sc != null) {
      var sct = sc.t.get();
      for (i in sct.interfaces) {
        if (i.t.get().name == 'IComponent') return null;
      }
      sc = sct.superClass;
    }

    // Otherwise add the required fields
    var fields = Context.getBuildFields();
    var concat = (macro class {
      /**
       * The Component's Class name, represented as either a String or as a Type.
       *
       * Example:
       * ```haxe
       * var myComponent = new MyComponent();
       * trace(myComponent.component_type == MyComponent); // true
       * trace(myComponent.component_type == "MyComponent"); // also true
       * ```
       */
      public var component_type(get, never):cog.IComponent.ComponentType;
      /**
       * The `Components` object that currently owns this Component.
       */
      public var owner(default, null):cog.Components = null;
      /**
       * Optional callback method that gets called when this Component is added to a `Components` object.
       */
      public var owner_added:cog.Components->Void = null;
      /**
       * Optional callback method that gets called when this Component is removed from a `Components` object.
       */
      public var owner_removed:Void->Void = null;
      /**
       * Removes this Component's owner object, if it has one.
       */
      public function remove_owner() {
        if (owner != null) owner.remove(component_type);
      }

      inline function get_component_type():cog.IComponent.ComponentType return this;
    }).fields;

    return fields.concat(concat);
  }

  static function build_node_class(params:Array<Type>):ComplexType {
    var paramNames = [for (param in params) param.getClass().name.split('.').pop()].join("");
    var name = 'Node$paramNames';
    if (!type_exists('cog.nodes.$name')) {
      var pos = Context.currentPos();
      var fields:Array<Field> = [];
      var constructorExprs:Array<Expr> = [];
      var regex = ~/(?<!^)([A-Z])/g;
      var componentTypes:Array<Expr> = [];

      // Add an Expr to get the 'components' to the constructor
      constructorExprs.push(macro {
        this.owner = owner;
        name = $v{name};
      });

      // Loop through any custom data fields and add a getter for it
      if (Lambda.count(dataFields) > 0) {
        for (kv in dataFields.keyValueIterator()) {
          var dataField = kv.key;
          var dataType = Context.toComplexType(Context.getType(kv.value));

          // Add the property field
          fields.push({
            name: dataField,
            access: [Access.APublic],
            kind: FProp("get", "null", dataType),
            pos: pos
          });

          // Add the getter
          fields.push({
            name: "get_" + dataField,
            access: [Access.APrivate, Access.AInline],
            kind: FFun({
              expr: macro return owner.$dataField,
              ret: dataType,
              args: []
            }),
            pos: pos,
          });
        }
      }

      // Loop through the params and add them to the Node's fields
      for (param in params) {
        var paramClass = param.getClass();

        // TODO - update this to check for IComponent interface
        // Check if param is a Component. throw an exception if not
        // var componentClass = Context.getType('cog.IComponent').getClass();
        // if (!is_subclass(paramClass, componentClass)) throw('Class `${paramClass.name}` does not extend `cog.Component`.');

        // Make the param name snake_case
        var paramName = '';
        var testName = paramClass.name;
        while (regex.match(testName)) {
          paramName += regex.matchedLeft() + '_' + regex.matched(1);
          testName = regex.matchedRight();
        }
        paramName += testName;
        paramName = paramName.toLowerCase();

        // Add the Component to the Node's fields
        fields.push({
          name: paramName,
          pos: pos,
          kind: FVar(param.toComplexType()),
          access: [APublic]
        });

        var componentPath = paramClass.pack.concat([paramClass.name]);
        if (componentPath.length <= 1) componentPath.insert(0, paramClass.module);

        // Add an expression to get the component in the Node's constructor
        constructorExprs.push(macro this.$paramName = owner.get($p{componentPath}));
        // Add an expression for the `component_types` variable
        componentTypes.push(macro $p{componentPath});
      }

      // Create a static field to contain Component references
      fields.push({
        name: 'component_types',
        access: [AStatic, APublic, AFinal],
        pos: pos,
        kind: FVar(macro:Array<cog.IComponent.ComponentType>, macro $a{componentTypes})
      });

      // Create the Constructor
      fields.push({
        name: "new",
        access: [APublic],
        pos: pos,
        kind: FFun({
          args: [{name: 'owner', type: TPath({name: 'Components', pack: ['cog']})}],
          expr: macro $b{constructorExprs},
          ret: macro:Void
        })
      });

      Context.defineType({
        pack: ['cog', 'nodes'],
        name: name,
        pos: pos,
        params: [],
        kind: TDClass({
          pack: ['cog'],
          name: "Node",
          sub: "NodeBase",
        }),
        fields: fields
      });
    }
    return TPath({pack: ['cog', 'nodes'], name: name, params: []});
  }

  static function build_signal_class(params:Array<Type>):ComplexType {
    var numParams = params.length;
    var name = 'Signal$numParams';

    if (!type_exists('cog.signals.$name')) {
      var typeParams:Array<TypeParamDecl> = [];
      var superClassFunctionArgs:Array<ComplexType> = [];
      var dispatchArgs:Array<FunctionArg> = [];
      var listenerCallParams:Array<Expr> = [];
      for (i in 0...numParams) {
        typeParams.push({name: 'T$i'});
        superClassFunctionArgs.push(TPath({name: 'T$i', pack: []}));
        dispatchArgs.push({name: 'arg$i', type: TPath({name: 'T$i', pack: []})});
        listenerCallParams.push(macro $i{'arg$i'});
      }

      var pos = Context.currentPos();

      Context.defineType({
        pack: ['cog', 'signals'],
        name: name,
        pos: pos,
        params: typeParams,
        kind: TDClass({
          pack: ['cog'],
          name: "Signal",
          sub: "SignalBase",
          params: [TPType(TFunction(superClassFunctionArgs, macro:Void))]
        }),
        fields: [
          {
            name: "dispatch",
            access: [APublic],
            pos: pos,
            kind: FFun({
              args: dispatchArgs,
              ret: macro:Void,
              expr: macro {
                start_dispatch();
                var conn = head;
                while (conn != null) {
                  conn.listener($a{listenerCallParams});
                  if (conn.once) conn.dispose();
                  conn = conn.next;
                }
                end_dispatch();
              }
            })
          }
        ]
      });
    }

    return TPath({pack: ['cog', 'signals'], name: name, params: [for (t in params) TPType(t.toComplexType())]});
  }
}
#end
