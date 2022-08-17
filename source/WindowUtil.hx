package;

#if false
import lime.ui.Window;
import flixel.util.FlxColor;

// will work on this later im so fucking tired
@:native("HWND__") extern class HWNDStruct {}
typedef HWND = cpp.Pointer<HWNDStruct>;
typedef BOOL = Int;
typedef BYTE = Int;
typedef LONG = Int;
typedef DWORD = LONG;
typedef COLORREF = DWORD;

@:cppFileCode('
#include <windows.h>
#include <SDL_syswm.h>
')
class WindowUtil {
	@:native("SetWindowLongA") @:extern
	private static function setWindowLong(hWnd:HWND, nIndex:Int, dwNewLong:LONG):LONG return null;

	@:native("GetWindowLongA") @:extern
	private static function getWindowLong(hWnd:HWND, nIndex:Int):LONG return null;

	@:native("SetLayeredWindowAttributes") @:extern
	private static function setLayeredWindowAttributes(hwnd:HWND, crKey:COLORREF, bAlpha:BYTE, dwFlags:DWORD):BOOL return null;

	@:native("GetLastError") @:extern
	private static function _getLastError():DWORD return null;
	private static function getLastError():String return Std.string(_getLastError());
	
	@:native("GWL_EXSTYLE") @:extern
	private static var EXSTYLE:Int;
	
	@:native("WS_EX_LAYERED") @:extern
	private static var EX_LAYERED:Int;
	
	@:native("LWA_COLORKEY") @:extern
	private static var COLORKEY:DWORD;
	
	public static function getSDLWindow(limeWin:Window):Dynamic
		@:privateAccess return limeWin.__backend.handle;
	
	@:functionCode("
		SDL_SysWMinfo wminfo;
		SDL_VERSION(&wminfo.version);

		if (SDL_GetWindowWMInfo(sdlWin, &wminfo) == 1) {
			HWND hwnd = wminfo.info.win.window;
			return hwnd;
		}
	")
	public static function getSDLWindowHWND(sdlWin:Dynamic):HWND return null;
	
	public static function getWindowHWND(win:Window):HWND
		return getSDLWindowHWND(getSDLWindow(win));
	
	public static function setWindowBackward(win:Window) {
		var win:HWND = getWindowHWND(win);
		if (win == null) throw "Can't get Window Handle";
		if (setWindowLong(win, EXSTYLE, getWindowLong(win, EXSTYLE) ^ EX_LAYERED) == 0) throw getLastError();
	}
	
	public static function setWindowColor(win:Window, color:FlxColor) {
		var win:HWND = getWindowHWND(win);
		if (win == null) throw "Can't get Window Handle";
		if (setWindowLong(win, EXSTYLE, getWindowLong(win, EXSTYLE) | EX_LAYERED) == 0) throw getLastError();
		if (setLayeredWindowAttributes(win, color, color.alpha, COLORKEY) == 0) throw getLastError();
	}
}
#else
class WindowUtil {
	public static function getSDLWindow(limeWin:Dynamic):Dynamic
		return null;
	
	public static function getSDLWindowHWND(sdlWin:Dynamic):Dynamic
		return null;
	
	public static function getWindowHWND(win:Dynamic):Dynamic
		return null;
	
	public static function setWindowBackward(win:Dynamic)
		return null;
	
	public static function setWindowColor(win:Dynamic, color:Int)
		return null;
}
#end
