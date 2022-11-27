package editors;

#if LUA_ALLOWED
import llua.Lua;
import llua.LuaL;
import llua.State;
import llua.Convert;
#end

using StringTools;

class EditorLua {
	public static var Function_Stop = 1;
	public static var Function_Continue = 0;

	#if LUA_ALLOWED
	public var lua:State = null;
	#end

	public function new(script:String) {
		
	}
	
	public function call(event:String, args:Array<Dynamic>):Dynamic {
		return null;
	}

	public function set(variable:String, data:Dynamic) {
		
	}

	public function stop() {
		
	}
}