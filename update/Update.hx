// https://github.com/YoshiCrafter29/CodenameEngine/blob/main/update/Update.hx

import haxe.Json;
import sys.FileSystem;

typedef Library = {
	var name:String;
	var type:String;
	var version:String;
	var dir:String;
	var ref:String;
	var url:String;
}

class Update {
	public static function main() {
		if (!FileSystem.exists('.haxelib')) FileSystem.createDirectory('.haxelib');
		Sys.println("Preparing installation...");
		
		for (lib in json) {
			switch(lib.type) {
				case "haxelib":
					Sys.println('Installing "${lib.name}"...');             
					Sys.command('haxelib install ${lib.name} ${lib.version != null ? " " + lib.version : " "}');
				case "git":
					Sys.println('Installing "${lib.name}" from git url "${lib.url}"');
					Sys.command('haxelib git ${lib.name} ${lib.url}');
				default:
					Sys.println('Cannot resolve library of type "${lib.type}"');
			}
		}
	}
}