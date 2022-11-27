package;

import flixel.input.keyboard.FlxKey;
import flixel.graphics.FlxGraphic;
import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxState;
import openfl.Assets;
import openfl.Lib;
import openfl.display.FPS;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.display.StageScaleMode;

//crash handler stuff
#if CRASH_HANDLER
import lime.app.Application;
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
import haxe.io.Path;
import Discord.DiscordClient;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
#end

using StringTools;

class Main extends Sprite
{
	var gameWidth:Int = 1280; // Width of the game in pixels (might be less / more in actual pixels depending on your zoom).
	var gameHeight:Int = 720; // Height of the game in pixels (might be less / more in actual pixels depending on your zoom).
	var initialState:Class<FlxState> = TitleState; // The FlxState the game starts with.
	var framerate:Int = 60; // How many frames per second the game should run at.
	var skipSplash:Bool = true; // Whether to skip the flixel splash screen that appears in release mode.
	var startFullscreen:Bool = false; // Whether to start the game in fullscreen on desktop targets
	public static var fpsVar:FPS;

	// You can pretty much ignore everything from here on - your code should go in your states.
	
	public static var fullscreenKeys:Array<FlxKey> = [FlxKey.F11];
	public static var focused:Bool = true;

	public static function main():Void
	{
		Lib.current.addChild(new Main());
	}

	public function new()
	{
		super();

		if (stage != null)
		{
			init();
		}
		else
		{
			addEventListener(Event.ADDED_TO_STAGE, init);
		}
	}

	private function init(?E:Event):Void
	{
		if (hasEventListener(Event.ADDED_TO_STAGE))
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
		}

		setupGame();
	}

	private function setupGame():Void
	{
		Lib.current.stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
		Lib.current.stage.addEventListener(KeyboardEvent.KEY_DOWN, handleInput);

		#if !debug
		initialState = TitleState;
		#end
	
		ClientPrefs.loadDefaultKeys();
		addChild(new FlxGame(gameWidth, gameHeight, initialState, #if (flixel < "5.0.0") 1,#end framerate, framerate, skipSplash, startFullscreen));

		fpsVar = new FPS(3, 3, 0xFFFFFF);
		addChild(fpsVar);
		Lib.current.stage.align = "tl";
		Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
		
		fpsVar.showFPS = ClientPrefs.showFPS;
		fpsVar.showMem = ClientPrefs.showMem;
		fpsVar.showMemPeak = ClientPrefs.showMemPeak;
		fpsVar.showGc = ClientPrefs.showGc;
		fpsVar.showGLStats = ClientPrefs.showGLStats;

		FlxG.signals.focusGained.add(onFocus);
		FlxG.signals.focusLost.add(onFocusLost);
		
		#if html5
		FlxG.autoPause = false;
		FlxG.mouse.visible = false;
		#end
		
		#if CRASH_HANDLER
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
		#end
	}
	
	private function handleInput(evt:KeyboardEvent) {
		if (fullscreenKeys.contains(CoolUtil.flKeyToFlx(evt.keyCode))) FlxG.fullscreen = !FlxG.fullscreen;
	}
	
	private function onFocus() {
		focused = true;
	}
	
	var woah:Int = 0;
	private function onFocusLost() {
		woah = 3;
		focused = false;
	}
	
	private function onEnterFrame(_) {
		// CLEVER WAY TO SECRETLY GC LMAO
		if (!focused && woah > 0) {
			Paths.compress(8);
			woah--;
		}
	}

	// Code was entirely made by sqirra-rng for their fnf engine named "Izzy Engine", big props to them!!!
	// very cool person for real they don't get enough credit for their work
	#if CRASH_HANDLER
	function onCrash(e:UncaughtErrorEvent):Void
	{
		var errMsg:String = "";
		var path:String;
		var callStack:Array<StackItem> = CallStack.exceptionStack(true);
		var dateNow:String = Date.now().toString();

		dateNow = dateNow.replace(" ", "_");
		dateNow = dateNow.replace(":", "'");

		path = "./crash/" + "PsychEngine_" + dateNow + ".txt";

		for (stackItem in callStack)
		{
			switch (stackItem)
			{
				case FilePos(s, file, line, column):
					errMsg += file + " (line " + line + ")\n";
				default:
					Sys.println(stackItem);
			}
		}

		errMsg += "\nUncaught Error: " + e.error + "\nPlease report this error to the GitHub page: https://github.com/ShadowMario/FNF-PsychEngine\n\n> Crash Handler written by: sqirra-rng";

		if (!FileSystem.exists("./crash/"))
			FileSystem.createDirectory("./crash/");

		File.saveContent(path, errMsg + "\n");

		Sys.println(errMsg);
		Sys.println("Crash dump saved in " + Path.normalize(path));

		Application.current.window.alert(errMsg, "Error!");
		DiscordClient.shutdown();
		Sys.exit(1);
	}
	#end
}
