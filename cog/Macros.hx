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
            var fullNodeName = '${ct.pack.join('.')}.${ct.name}'.split('.');
            // Make the expression to create the `Nodes` when the system is added
            addNodesExpr.push(macro $i{fieldName} = new cog.Nodes(engine, components -> new $typePath(components),
              (components) -> components.has_all($p{fullNodeName}.component_types)));
            // Make the expressions to destroy the `Nodes` when the system is removed
            removeNodesExpr.push(macro {
              $i{fieldName}.dispose();
              $i{fieldName} = null;
            });
          default:
            throw('@:nodes metadata can only be used on a variable of `Node<T>` class');
        }
      }
    }

    var pos = Context.currentPos();

    // add expressions to create nodelists
    if (addNodesExpr.length > 0) fields.push({
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
    if (removeNodesExpr.length > 0) fields.push({
      access: [AOverride, AInline],
      name: 'remove_nodes',
      pos: pos,
      kind: FFun({
        args: [],
        ret: macro:Void,
        expr: macro $b{removeNodesExpr}
      })
    });

    return fields;
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

  static function build_node_class(params:Array<Type>):ComplexType {
    var paramNames = [for (param in params) param.getClass().name.split('.').pop()].join("");
    var name = 'Node$paramNames';
    if (!type_exists('cog.nodes.$name')) {
      var pos = Context.currentPos();
      var fields:Array<Field> = [];
      var constructorExprs:Array<Expr> = [];
      var regex = ~/(?<!^)([A-Z])/g;
      var componentClass = Context.getType('cog.Component').getClass();
      var componentTypes:Array<Expr> = [];

      // Add an Expr to get the 'components' to the constructor
      constructorExprs.push(macro {
        this.components = components;
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
              expr: macro return components.$dataField,
              ret: dataType,
              args: []
            }),
            pos: pos,
          });
        }
      }

      // Loop through the params and add them to the Node's fields
      for (param in params) {
        // Check if param is a Component. throw an exception if not
        var paramClass = param.getClass();
        if (!is_subclass(paramClass, componentClass)) throw('Class `${paramClass.name}` does not extend `cog.Component`.');

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

        // var componentPath = '${paramClass.pack.join('.')}.${paramClass.name}'.split('.').filter(str -> str.length > 0);

        // Add an expression to get the component in the Node's constructor
        // TODO - fix naming conflict with having Component classes in `components` module
        constructorExprs.push(macro this.$paramName = components.get($p{componentPath}));
        // Add an expression for the `component_types` variable
        componentTypes.push(macro $p{componentPath});
      }

      // Create a static field to contain Component references
      fields.push({
        name: 'component_types',
        access: [AStatic, APublic],
        pos: pos,
        kind: FVar(macro:Array<cog.Component.ComponentType>, macro $a{componentTypes})
      });

      // Create the Constructor
      fields.push({
        name: "new",
        access: [APublic],
        pos: pos,
        kind: FFun({
          args: [{name: 'components', type: TPath({name: 'Components', pack: ['cog']})}],
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
