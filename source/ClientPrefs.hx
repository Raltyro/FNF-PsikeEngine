package;

import flixel.FlxG;
import flixel.util.FlxSave;
import flixel.input.keyboard.FlxKey;
import flixel.graphics.FlxGraphic;
import lime.app.Application;
import Controls;

class ClientPrefs {
	public static var downScroll:Bool = false;
	public static var middleScroll:Bool = false;
	public static var opponentStrums:Bool = true;
	public static var autoPause:Bool = true;
	public static var autoPausePlayState:Bool = true;
	public static var showFPS:Bool = true;
	public static var showMem:Bool = true;
	public static var showMemPeak:Bool = true;
	public static var showGc:Bool = false;
	public static var showGLStats:Bool = false;
	public static var flashing:Bool = true;
	public static var globalAntialiasing:Bool = true;
	public static var noteSplashes:Bool = true;
	public static var lowQuality:Bool = false;
	public static var shaders:Bool = true;
	public static var framerate:Int = 60;
	public static var cursing:Bool = true;
	public static var violence:Bool = true;
	public static var camZooms:Bool = true;
	public static var hideHud:Bool = false;
	public static var noteOffset:Int = 0;
	public static var arrowHSV:Array<Array<Int>> = [[0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]];
	public static var ghostTapping:Bool = true;
	public static var timeBarType:String = 'Time Left';
	public static var scoreZoom:Bool = true;
	public static var gameOverInfos:Bool = true;
	public static var noReset:Bool = false;
	public static var healthBarAlpha:Float = 1;
	public static var controllerMode:Bool = true; // deprecated
	public static var hitsoundVolume:Float = 0;
	public static var pauseMusic:String = 'Tea Time';
	public static var checkForUpdates:Bool = true;
	public static var comboStacking:Bool = true;
	public static var gameplaySettings:Map<String, Dynamic> = [
		'scrollspeed' => 1.0,
		'scrolltype' => 'multiplicative', 
		// anyone reading this, amod is multiplicative speed mod, cmod is constant speed mod, and xmod is bpm based speed mod.
		// an amod example would be chartSpeed * multiplier
		// cmod would just be constantSpeed = chartSpeed
		// and xmod basically works by basing the speed on the bpm.
		// iirc (beatsPerSecond * (conductorToNoteDifference / 1000)) * noteSize (110 or something like that depending on it, prolly just use note.height)
		// bps is calculated by bpm / 60
		// oh yeah and you'd have to actually convert the difference to seconds which I already do, because this is based on beats and stuff. but it should work
		// just fine. but I wont implement it because I don't know how you handle sustains and other stuff like that.
		// oh yeah when you calculate the bps divide it by the songSpeed or rate because it wont scroll correctly when speeds exist.
		'songspeed' => 1.0,
		'healthgain' => 1.0,
		'healthloss' => 1.0,
		'instakill' => false,
		'practice' => false,
		'botplay' => false,
		'opponentplay' => false
	];

	public static var comboOffset:Array<Int> = [0, 0, 0, 0, 0, 0];
	public static var scoresOnSustains:Bool = true;
	public static var missSustainsOnce:Bool = true;
	public static var ratingOffset:Int = 0;
	public static var sickWindow:Int = 45;
	public static var goodWindow:Int = 90;
	public static var badWindow:Int = 135;
	public static var safeFrames:Float = 10;
	
	public static var hardwareCache:Bool = true;
	public static var isHardCInited:Bool = false;
	public static var streamMusic:Bool = true;
	public static var isStreMInited:Bool = false;

	//Every key has two binds, add your key bind down here and then add your control on options/ControlsSubState.hx and Controls.hx
	public static var keyBinds:Map<String, Array<FlxKey>> = [
		//Key Bind, Name for ControlsSubState
		'note_left'		=> [A, LEFT],
		'note_down'		=> [S, DOWN],
		'note_up'		=> [W, UP],
		'note_right'	=> [D, RIGHT],
		
		'ui_left'		=> [A, LEFT],
		'ui_down'		=> [S, DOWN],
		'ui_up'			=> [W, UP],
		'ui_right'		=> [D, RIGHT],
		
		'accept'		=> [SPACE, ENTER],
		'back'			=> [BACKSPACE, ESCAPE],
		'pause'			=> [ENTER, ESCAPE],
		'reset'			=> [R, NONE],
		
		'volume_mute'	=> [ZERO, NONE],
		'volume_up'		=> [NUMPADPLUS, PLUS],
		'volume_down'	=> [NUMPADMINUS, MINUS],
		
		'debug_1'		=> [SEVEN, NONE],
		'debug_2'		=> [EIGHT, NONE]
	];
	public static var defaultKeys:Map<String, Array<FlxKey>> = null;

	public static function loadDefaultKeys() {
		defaultKeys = keyBinds.copy();
		//trace(defaultKeys);
	}

	public static var stringsToSave:Array<String> = [
		"downScroll", "middleScroll", "opponentStrums",
		"showFPS", "showMem", "showMemPeak", "showGc",
		"showGLStats", "flashing", "globalAntialiasing",
		"noteSplashes", "lowQuality", "shaders",
		"framerate", "camZooms", "noteOffset",
		"hideHud", "arrowHSV", "ghostTapping",
		"timeBarType", "scoreZoom", "noReset",
		"healthBarAlpha", "comboOffset", "ratingOffset",
		"sickWindow", "goodWindow", "badWindow", "safeFrames",
		"gameplaySettings", "controllerMode", "hitsoundVolume",
		"pauseMusic", "checkForUpdates", "comboStacking",
		"autoPausePlayState", "gameOverInfos",
		"scoresOnSustains", "missSustainsOnce",
		"hardwareCache", "streamMusic",
		//"cursing", "violence",
		#if !html5
		"autoPause",
		#end
		""
	];
	public static var stringsNotToLoad:Array<String> = [
		"gameplaySettings",
	];

	public static var saveControls:FlxSave = new FlxSave();

	public static function saveSettings() {
		for (i in stringsToSave) Reflect.setField(FlxG.save.data, i, Reflect.field(ClientPrefs, i));
		FlxG.save.data.achievementsMap = Achievements.achievementsMap;
		FlxG.save.data.henchmenDeath = Achievements.henchmenDeath;

		saveControls.data.customControls = keyBinds;

		FlxG.save.flush();
		saveControls.flush();

		FlxG.log.add("Settings saved!");
	}

	inline public static function bind() {
		final savePath = CoolUtil.getSavePath("ninjamuffin99");
		final psychPath = CoolUtil.getSavePath("ninjamuffin99", 'ShadowMario/PsychEngine');

		FlxG.save.bind('funkin', savePath);
		saveControls.bind('controls_v2', savePath);

		#if MERGE_PSYCH_DATA
		if (FlxG.save.isEmpty() && savePath != psychPath) {
			final oldSave = new FlxSave();

			if (oldSave.bind('funkin', psychPath)) FlxG.save.mergeData(oldSave.data);
			if (oldSave.bind('controls_v2', psychPath)) saveControls.mergeData(oldSave.data);

			oldSave.destroy();
		}
		#end
	}

	public static function loadPrefs() {
		bind();

		var v:Any;
		for (i in stringsToSave) {
			if ((v = Reflect.field(FlxG.save.data, i)) != null) {
				if (!stringsNotToLoad.contains(i)) Reflect.setField(ClientPrefs, i, v);

				switch(i) {
					#if (!html5)
					case "autoPause": {
						FlxG.autoPause = FlxG.save.data.autoPause;
					}
					#end

					case "framerate": {
						if (framerate > FlxG.drawFramerate) {
							FlxG.updateFramerate = framerate;
							FlxG.drawFramerate = framerate;
						}
						else {
							FlxG.drawFramerate = framerate;
							FlxG.updateFramerate = framerate;
						}
					}

					case "gameplaySettings": {
						var savedMap:Map<String, Dynamic> = FlxG.save.data.gameplaySettings;
						try for (name => value in savedMap) {
							gameplaySettings.set(name, value);
						}
						catch(exception)
							trace("Gameplay Settings are null!");
					}

					case "hardwareCache": if (!isHardCInited) {
						Paths.hardwareCache = hardwareCache;
						isHardCInited = true;
					}

					case "streamMusic": if (!isStreMInited) {
						Paths.streamMusic = streamMusic;
						isStreMInited = true;
					}
				}
			}
		}

		#if (!html5)
		if (FlxG.save.data.framerate == null) {
			var refreshRate = Application.current.window.displayMode.refreshRate;
			if (framerate != refreshRate) framerate = Math.floor(CoolUtil.boundTo(refreshRate, 60, 240));
		}
		#end

		if (saveControls.data.customControls != null) {
			var loadedControls:Map<String, Array<FlxKey>> = saveControls.data.customControls;
			for (control => keys in loadedControls) keyBinds.set(control, keys);
			reloadControls();
		}
	}

	inline public static function getGameplaySetting(name:String, defaultValue:Dynamic):Dynamic {
		return /*PlayState.isStoryMode ? defaultValue : */ (gameplaySettings.exists(name) ? gameplaySettings.get(name) : defaultValue);
	}

	public static function reloadControls() {
		PlayerSettings.player1.controls.setKeyboardScheme(KeyboardScheme.Solo);

		Main.muteKeys = copyKey(keyBinds.get('volume_mute'));
		Main.volumeDownKeys = copyKey(keyBinds.get('volume_down'));
		Main.volumeUpKeys = copyKey(keyBinds.get('volume_up'));
		FlxG.sound.muteKeys = Main.muteKeys;
		FlxG.sound.volumeDownKeys = Main.volumeDownKeys;
		FlxG.sound.volumeUpKeys = Main.volumeUpKeys;
	}

	public static function copyKey(arrayToCopy:Array<FlxKey>):Array<FlxKey> {
		var copiedArray:Array<FlxKey> = arrayToCopy.copy();
		var i:Int = 0;
		var len:Int = copiedArray.length;

		while (i < len) {
			if(copiedArray[i] == NONE) {
				copiedArray.remove(NONE);
				--i;
			}
			i++;
			len = copiedArray.length;
		}
		return copiedArray;
	}
}
