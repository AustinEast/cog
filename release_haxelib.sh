#!/bin/sh
rm -f cog.zip
zip -r cog.zip cog *.md *.json *.hxml run.n
haxelib submit cog.zip $HAXELIB_PWD --always