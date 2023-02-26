package;

import lime.app.Application;

import openfl.display.Sprite;
import openfl.display.StageScaleMode;
import openfl.display.FPS;
import openfl.events.KeyboardEvent;
import openfl.events.Event;
import openfl.Lib;

import flixel.input.keyboard.FlxKey;
import flixel.FlxG;
import flixel.FlxGame;

//import screenshotplugin.ScreenShotPlugin;

#if desktop
import Discord.DiscordClient;
#end

#if CRASH_HANDLER
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
#end

using StringTools;

class Main extends Sprite {
	var game = {
		width: 1280, // WINDOW width
		height: 720, // WINDOW height
		initialState: TitleState, // initial game state
		zoom: -1.0, // game state bounds
		framerate: 60, // default framerate
		skipSplash: true, // if the default flixel splash screen should be skipped
		startFullscreen: false // if the game should start at fullscreen mode
	};

	public static var args:Array<String>;
	public static var current:Main;
	public static var fpsVar:FPS;

	// You can pretty much ignore everything from here on - your code should go in your states.

	public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
	public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
	public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];
	public static var fullscreenKeys:Array<FlxKey> = [FlxKey.F11];
	public static var screenshotKeys:Array<FlxKey> = [FlxKey.PRINTSCREEN];
	public static var focused:Bool = true;

	public static function main():Void {
		args = Sys.args();
		Lib.current.addChild(current = new Main());
	}

	public function new() {
		super();

		if (stage != null) init();
		else addEventListener(Event.ADDED_TO_STAGE, init);
	}

	private function init(?E:Event):Void {
		if (hasEventListener(Event.ADDED_TO_STAGE))
			removeEventListener(Event.ADDED_TO_STAGE, init);

		setupGame();
	}

	private function setupGame():Void {
		var stageWidth:Int = Lib.current.stage.stageWidth;
		var stageHeight:Int = Lib.current.stage.stageHeight;

		if (game.zoom == -1.0) {
			var ratioX:Float = stageWidth / game.width;
			var ratioY:Float = stageHeight / game.height;
			game.zoom = Math.min(ratioX, ratioY);
			game.width = Math.ceil(stageWidth / game.zoom);
			game.height = Math.ceil(stageHeight / game.zoom);
		}

		Lib.current.stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
		Lib.current.stage.addEventListener(KeyboardEvent.KEY_DOWN, handleInput);

		Lib.current.stage.align = "tl";
		Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;

		FlxG.signals.postGameReset.add(onGameReset);
		FlxG.signals.focusGained.add(onFocus);
		FlxG.signals.focusLost.add(onFocusLost);

		ClientPrefs.loadDefaultKeys();
		ClientPrefs.bind();
		addChild(new FlxGame(game.width, game.height, game.initialState, #if (flixel < "5.0.0") game.zoom, #end game.framerate, game.framerate, game.skipSplash, game.startFullscreen));

		//ScreenShotPlugin.screenshotKeys = screenshotKeys;
		//FlxG.plugins.add(new ScreenShotPlugin());

		#if CRASH_HANDLER
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
		#end

		#if desktop
		if (!DiscordClient.isInitialized) {
			DiscordClient.initialize();
			Application.current.window.onClose.add(function() {
				DiscordClient.shutdown();
			});
		}
		#end
	}

	private function handleInput(evt:KeyboardEvent) {
		if (fullscreenKeys.contains(CoolUtil.flKeyToFlx(evt.keyCode))) FlxG.fullscreen = !FlxG.fullscreen;
	}

	private function onGameReset() {
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		PlayerSettings.init();
		ClientPrefs.loadPrefs();

		Highscore.load();

		#if MODS_ALLOWED
		Paths.pushGlobalMods();
		#end

		if (FlxG.save.data != null) {
			if (FlxG.save.data.fullscreen != null) FlxG.fullscreen = FlxG.save.data.fullscreen;
			if (FlxG.save.data.weekCompleted != null) StoryMenuState.weekCompleted = FlxG.save.data.weekCompleted;
		}

		fpsVar = new FPS(3, 3, 0xFFFFFF);
		addChild(fpsVar);

		fpsVar.showFPS = ClientPrefs.showFPS;
		fpsVar.showMem = ClientPrefs.showMem;
		fpsVar.showMemPeak = ClientPrefs.showMemPeak;
		fpsVar.showGc = ClientPrefs.showGc;
		fpsVar.showGLStats = ClientPrefs.showGLStats;

		FlxG.fixedTimestep = false;
		FlxG.mouse.visible = false;
		FlxG.sound.muteKeys = muteKeys;
		FlxG.sound.volumeDownKeys = volumeDownKeys;
		FlxG.sound.volumeUpKeys = volumeUpKeys;
		FlxG.keys.preventDefaultKeys = [TAB];
		FlxG.game.focusLostFramerate = 8;

		#if html5
		FlxG.autoPause = false;
		FlxG.mouse.visible = false;
		#end

		#if CHECK_FOR_UPDATES
		CoolUtil.checkForUpdates(function(mustUpdate:Bool) {
			if (ClientPrefs.checkForUpdates && mustUpdate) trace("Must Update!! Showing OutdatedState after TitleState");
		});
		#end
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
		//if (!focused && woah > 0) {
		//	Paths.compress(8);
		//	woah--;
		//}
	}

	// Code was entirely made by sqirra-rng for their fnf engine named "Izzy Engine", big props to them!!!
	// very cool person for real they don't get enough credit for their work
	#if CRASH_HANDLER
	function onCrash(e:UncaughtErrorEvent):Void {
		var errMsg:String = "";
		var path:String;
		var callStack:Array<StackItem> = CallStack.exceptionStack(true);
		var dateNow:String = Date.now().toString();

		dateNow = dateNow.replace(" ", "_");
		dateNow = dateNow.replace(":", "'");

		path = "./crash/" + "PsikeEngine_" + dateNow + ".txt";

		for (stackItem in callStack) {
			switch (stackItem) {
				case FilePos(s, file, line, column):
					errMsg += file + " (line " + line + ")\n";
				default:
					Sys.println(stackItem);
			}
		}

		errMsg += "\nUncaught Error: " + e.error + "\nPlease report this error to the GitHub page: https://github.com/Raltyro/FNF-PsikeEngine\n\n> Crash Handler written by: sqirra-rng";

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
