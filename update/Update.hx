// https://github.com/YoshiCrafter29/CodenameEngine/blob/main/update/Update.hx

import haxe.Json;

import sys.io.File;
import sys.io.Process;
import sys.FileSystem;

using StringTools;

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
		var isHMM = getProcessOutput('haxelib', ['list', 'hmm']).contains('hmm'), prevCwd = Sys.getCwd(), mainCwd;
		var json:Array<Library> = Json.parse(File.getContent('./hmm.json')).dependencies;
		if (isHMM) {
			if (!FileSystem.exists('.haxelib')) FileSystem.createDirectory('.haxelib');
			Sys.setCwd(mainCwd = '$prevCwd/.haxelib');
		}
		else
			Sys.setCwd(mainCwd = getProcessOutput('haxelib', ['config']).rtrim());

		try {
			Sys.println("Preparing installation...");

			for (lib in json) {
				switch(lib.type) {
					case "haxelib":
						Sys.println('Installing "${lib.name}"...');             
						Sys.command('haxelib install ${lib.name} ${lib.version != null ? " " + lib.version : " "} --quiet');
					case "git":
						if (!FileSystem.exists(lib.dir)) FileSystem.createDirectory(lib.dir);
						else if (!isHMM && FileSystem.exists('${lib.dir}/dev')) continue;

						Sys.println('Installing "${lib.name}" from git url "${lib.url}"');

						if (FileSystem.exists('${lib.dir}/git')) {
							Sys.setCwd('${mainCwd}/${lib.dir}/git');
							Sys.command('git pull');
						}
						else {
							Sys.setCwd('${mainCwd}/${lib.dir}');
							Sys.command('git clone --recurse-submodules ${lib.url} git');
							if (!isHMM) File.saveContent('.current', 'git');
						}
						Sys.setCwd(mainCwd);
					default:
						Sys.println('Cannot resolve library of type "${lib.type}"');
				}
			}
		}
		catch(e) {
			trace(e);
		}

		Sys.setCwd(prevCwd);
	}

	public static function getProcessOutput(cmd:String, args:Array<String>):String {
		try {
			var process = new Process(cmd, args), output = "";
			try {output = process.stdout.readAll().toString();}
			catch (_) {}

			process.close();
			return output;
		}
		catch (_) {
			return "";
		}
	}
}