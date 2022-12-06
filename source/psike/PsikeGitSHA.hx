package psike;

import flixel.system.macros.FlxGitSHA;
import haxe.macro.Context;
import haxe.macro.Expr;
import sys.io.Process;

using StringTools;

@:noCompletion
class PsikeGitSHA {
	private static function buildGitSHA():Array<Field> {
		var fields:Array<Field> = Context.getBuildFields();
		var sha:String = "";

		#if !display
		try
		{
			sha = flixel.system.macros.FlxGitSHA.getGitSHA(Sys.getCwd());
		}
		catch (_:Dynamic)
		{
			// make sure the build isn't cancelled if a Sys call fails
		}
		#end

		fields.push({
			name: "sha",
			doc: null,
			meta: [],
			access: [Access.APublic, Access.AStatic],
			kind: FieldType.FProp("default", "null", macro:Dynamic, macro $v{sha}),
			pos: Context.currentPos()
		});

		return fields;
	}
}