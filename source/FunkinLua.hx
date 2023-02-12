package;

#if LUA_ALLOWED
import llua.Lua;
import llua.LuaL;
import llua.State;
import llua.Convert;
#end

import animateatlas.AtlasFrameMaker;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.utils.Assets;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.effects.FlxTrail;
import flixel.input.keyboard.FlxKey;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.text.FlxText;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxPoint;
import flixel.system.FlxSound;
import flixel.util.FlxTimer;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.util.FlxColor;
import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.util.FlxSave;
import flixel.FlxG;

import Type.ValueType;
import DialogueBoxPsych;

#if (!flash && sys)
import flixel.addons.display.FlxRuntimeShader;
#end

#if sys
import sys.FileSystem;
import sys.io.File;

import haxe.io.Path;
#end

#if hscript
import hscript.Parser;
import hscript.Interp;
import hscript.Expr;
#end

#if desktop
import Discord;
#end

#if VIDEOS_ALLOWED
import hxcodec.VideoHandler;
import hxcodec.VideoSprite;
#end

using StringTools;

class FunkinLua {
	public static var Function_Stop:Dynamic = "##PSYCHLUA_FUNCTIONSTOP";
	public static var Function_Continue:Dynamic = "##PSYCHLUA_FUNCTIONCONTINUE";
	public static var Function_StopLua:Dynamic = "##PSYCHLUA_FUNCTIONSTOPLUA";

	#if hscript
	public static var allowedHaxeTypes(default, null):Array<Dynamic> = [Bool, Int, Float, String, Array];
	public static var hscript:HScript = null;
	#end

	public static function format(luaFile:String):String {
		return Path.normalize((luaFile = luaFile.toLowerCase()).endsWith('.lua') ? luaFile : '${luaFile}.lua');
	}

	public static function execute(script:String):FunkinLua {
		var lua:FunkinLua = new FunkinLua(script);
		if (PlayState.instance == null || FlxG.state != PlayState.instance) return lua;
		if (!lua.closed) PlayState.instance.luaArray.push(lua);
		return lua;
	}

	#if LUA_ALLOWED
	public var lua:State;
	#end
	public var globalScriptName:String = '';
	public var modDir:String = '';
	public var scriptName:String;
	public var closed:Bool = false;

	public function new(script:String) {
		if (!Path.isAbsolute(script)) { // any absoluted paths, fuck it.
			var dirs = (script = format(script)).split('/'), mod = Paths.mods(), index = -1;
			for (i in 0...dirs.length) {
				if (mod.startsWith(dirs[i])) {
					modDir = ((index = i + 1) < dirs.length && Paths.isValidModDir(dirs[index])) ? dirs[index] : '';
					break;
				}
			}

			if (modDir != '' || index != -1)
				globalScriptName = haxe.io.Path.join([for (i in (index + (modDir != '' ? 1 : 0))...dirs.length) dirs[i]]);
		}
		else globalScriptName = scriptName;
		scriptName = script;

		#if LUA_ALLOWED
		lua = LuaL.newstate();

		var result:Int = LuaL.loadfile(lua, script);
		if (result == Lua.LUA_OK) {
			LuaL.openlibs(lua);
			Lua_helper.init_callbacks(lua);

			initGlobals();

			Lua_helper.link_extra_arguments(lua, [this]);
			Lua_helper.link_static_callbacks(lua);

			// LuaL.dostring(lua, CLENSE);
			result = Lua.pcall(lua, 0, 0, 0);
		}

		if (result != Lua.LUA_OK) {
			var error:String = getErrorMessage();
			trace('Error on lua script "$script"! ' + error);

			#if windows
			lime.app.Application.current.window.alert(error, 'Error on lua script! "$script"');
			#else
			luaTrace('Error loading lua script: "$script"\n' + error, true, false, FlxColor.RED);
			#end

			stop();
			return;
		}

		trace('lua script "$script" loaded successfully');

		call('onCreate');
		if (closed) return stop();
		#end
	}

	#if LUA_ALLOWED
	public static var globals:Map<String, Any>;

	public function initGlobals() {
		// Song/Week shit
		set('curBpm', Conductor.bpm);
		set('bpm', PlayState.SONG.bpm);
		set('scrollSpeed', PlayState.SONG.speed);
		set('crochet', Conductor.crochet);
		set('stepCrochet', Conductor.stepCrochet);
		set('songLength', PlayState.instance.songLength);
		set('songName', PlayState.SONG.song);
		set('songPath', Paths.formatToSongPath(PlayState.SONG.song));
		set('startedCountdown', false);
		set('curStage', PlayState.SONG.stage);

		set('isStoryMode', PlayState.isStoryMode);
		set('difficulty', PlayState.storyDifficulty);

		var difficultyName:String = CoolUtil.difficulties[PlayState.storyDifficulty];
		set('difficultyName', difficultyName);
		set('difficultyPath', Paths.formatToSongPath(difficultyName));
		set('weekRaw', PlayState.storyWeek);
		set('week', WeekData.weeksList[PlayState.storyWeek]);
		set('seenCutscene', PlayState.seenCutscene);

		// Camera poo
		set('cameraX', 0);
		set('cameraY', 0);

		// Screen stuff
		set('screenWidth', FlxG.width);
		set('screenHeight', FlxG.height);

		// PlayState cringe ass nae nae bullcrap
		set('curBeat', 0);
		set('curStep', 0);
		set('curDecBeat', 0);
		set('curDecStep', 0);

		set('score', 0);
		set('misses', 0);
		set('hits', 0);

		set('rating', 0);
		set('ratingName', '');
		set('ratingFC', '');

		set('inGameOver', false);
		set('mustHitSection', false);
		set('altAnim', false);
		set('gfSection', false);

		// Gameplay settings
		set('healthGainMult', PlayState.instance.healthGain);
		set('healthLossMult', PlayState.instance.healthLoss);
		set('playbackRate', PlayState.instance.playbackRate);
		set('instakillOnMiss', PlayState.instance.instakillOnMiss);
		set('botPlay', PlayState.instance.cpuControlled);
		set('practice', PlayState.instance.practiceMode);

		for (i in 0...4) {
			set('defaultPlayerStrumX' + i, 0);
			set('defaultPlayerStrumY' + i, 0);
			set('defaultOpponentStrumX' + i, 0);
			set('defaultOpponentStrumY' + i, 0);
		}

		// Default character positions woooo
		set('defaultBoyfriendX', PlayState.instance.BF_X);
		set('defaultBoyfriendY', PlayState.instance.BF_Y);
		set('defaultOpponentX', PlayState.instance.DAD_X);
		set('defaultOpponentY', PlayState.instance.DAD_Y);
		set('defaultGirlfriendX', PlayState.instance.GF_X);
		set('defaultGirlfriendY', PlayState.instance.GF_Y);

		// Character shit
		set('boyfriendName', PlayState.SONG.player1);
		set('dadName', PlayState.SONG.player2);
		set('gfName', PlayState.SONG.gfVersion);

		// Some settings, no jokes
		set('downscroll', ClientPrefs.downScroll);
		set('middlescroll', ClientPrefs.middleScroll);
		set('framerate', ClientPrefs.framerate);
		set('ghostTapping', ClientPrefs.ghostTapping);
		set('hideHud', ClientPrefs.hideHud);
		set('timeBarType', ClientPrefs.timeBarType);
		set('scoreZoom', ClientPrefs.scoreZoom);
		set('cameraZoomOnBeat', ClientPrefs.camZooms);
		set('flashingLights', ClientPrefs.flashing);
		set('noteOffset', ClientPrefs.noteOffset);
		set('healthBarAlpha', ClientPrefs.healthBarAlpha);
		set('noResetButton', ClientPrefs.noReset);
		set('lowQuality', ClientPrefs.lowQuality);
		set('shadersEnabled', ClientPrefs.shaders);
		set('currentModDirectory', Paths.currentModDirectory);

		for (k => v in globals) set(k, v);

		// Lua shit
		set('Function_StopLua', Function_StopLua);
		set('Function_Stop', Function_Stop);
		set('Function_Continue', Function_Continue);

		set('luaDebugMode', false);
		set('luaDeprecatedWarnings', true);
		set('luaBackwardCompatibility', true);
		set('inChartEditor', false);

		set('version', MainMenuState.psychEngineVersion.trim());
		set('scriptName', scriptName);

		#if windows
		var os = 'windows';
		#elseif html5
		var os = 'browser';
		#else
		var os = Sys.systemName().toLowerCase();
		#end
		set('buildTarget', os);
	}

	public static function initStatics() {
		Convert.traceUnsupported = false;
		globals = [];

		#if hscript
		hscript = new HScript();
		#end

		// custom substate
		Lua_helper.set_static_callback("openCustomSubstate", function(_, name:String, pauseGame:Bool = false):Void {
			if (pauseGame) {
				PlayState.instance.persistentUpdate = false;
				PlayState.instance.persistentDraw = true;
				PlayState.instance.paused = true;
				if (FlxG.sound.music != null) {
					FlxG.sound.music.pause();
					PlayState.instance.vocals.pause();
				}
			}
			PlayState.instance.openSubState(new CustomSubstate(name));
		});

		Lua_helper.set_static_callback("closeCustomSubstate", function(_):Bool {
			if (CustomSubstate.instance == null) return false;
			PlayState.instance.closeSubState();
			CustomSubstate.instance = null;
			return true;
		});


		// shader shit
		Lua_helper.set_static_callback("initLuaShader", function(l:FunkinLua, name:String, glslVersion:Int = 120):Bool {
			if (!ClientPrefs.shaders) return false;

			#if (!flash && MODS_ALLOWED && sys)
			return PlayState.instance.initLuaShader(name, glslVersion);
			#else
			l.luaTrace("initLuaShader: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return false;
			#end
		});

		Lua_helper.set_static_callback("setSpriteShader", function(l:FunkinLua, obj:String, shader:String):Bool {
			if (!ClientPrefs.shaders) return false;

			#if (!flash && MODS_ALLOWED && sys)
			if (!PlayState.instance.runtimeShaders.exists(shader) && !PlayState.instance.initLuaShader(shader)) {
				l.luaTrace('setSpriteShader: Shader $shader is missing!', false, false, FlxColor.RED);
				return false;
			}

			var leObj:FlxSprite = getVarInstance(obj, true, false);
			if (leObj != null) {
				var arr = PlayState.instance.runtimeShaders.get(shader);
				leObj.shader = new FlxRuntimeShader(arr[0], arr[1]);
				return true;
			}
			#else
			l.luaTrace("setSpriteShader: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			#end

			return false;
		});

		Lua_helper.set_static_callback("removeSpriteShader", function(_, obj:String):Bool {
			var leObj:FlxSprite = getVarInstance(obj, true, false);
			if (leObj != null) {
				leObj.shader = null;
				return true;
			}
			return false;
		});

		Lua_helper.set_static_callback("getShaderBool", function(l:FunkinLua, obj:String, prop:String):Dynamic {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			return shader != null ? shader.getBool(prop) : null;
			#else
			l.luaTrace("getShaderBool: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			#end
		});

		Lua_helper.set_static_callback("getShaderBoolArray", function(l:FunkinLua, obj:String, prop:String):Array<Bool> {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			return shader != null ? shader.getBoolArray(prop) : null;
			#else
			l.luaTrace("getShaderBoolArray: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			#end
		});

		Lua_helper.set_static_callback("getShaderInt", function(l:FunkinLua, obj:String, prop:String):Dynamic {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			return shader != null ? shader.getInt(prop) : null;
			#else
			l.luaTrace("getShaderInt: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			#end
		});

		Lua_helper.set_static_callback("getShaderIntArray", function(l:FunkinLua, obj:String, prop:String):Array<Int> {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			return shader != null ? shader.getIntArray(prop) : null;
			#else
			l.luaTrace("getShaderIntArray: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			#end
		});

		Lua_helper.set_static_callback("getShaderFloat", function(l:FunkinLua, obj:String, prop:String):Dynamic {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			return shader != null ? shader.getFloat(prop) : null;
			#else
			l.luaTrace("getShaderFloat: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			#end
		});

		Lua_helper.set_static_callback("getShaderFloatArray", function(l:FunkinLua, obj:String, prop:String):Array<Float> {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			return shader != null ? shader.getFloatArray(prop) : null;
			#else
			l.luaTrace("getShaderFloatArray: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			#end
		});

		Lua_helper.set_static_callback("setShaderBool", function(l:FunkinLua, obj:String, prop:String, value:Bool):Bool {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader != null) {
				shader.setBool(prop, value);
				return true;
			}
			#else
			l.luaTrace("setShaderBool: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			#end

			return false;
		});

		Lua_helper.set_static_callback("setShaderBoolArray", function(l:FunkinLua, obj:String, prop:String, values:Dynamic):Bool {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader != null) {
				shader.setBoolArray(prop, values);
				return true;
			}
			#else
			l.luaTrace("setShaderBoolArray: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			#end

			return false;
		});

		Lua_helper.set_static_callback("setShaderInt", function(l:FunkinLua, obj:String, prop:String, value:Int):Bool {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader != null) {
				shader.setInt(prop, value);
				return true;
			}
			#else
			l.luaTrace("setShaderInt: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			#end

			return false;
		});

		Lua_helper.set_static_callback("setShaderIntArray", function(l:FunkinLua, obj:String, prop:String, values:Dynamic):Bool {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader != null) {
				shader.setIntArray(prop, values);
				return true;
			}
			#else
			l.luaTrace("setShaderIntArray: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			#end

			return false;
		});

		Lua_helper.set_static_callback("setShaderFloat", function(l:FunkinLua, obj:String, prop:String, value:Float):Bool {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader != null) {
				shader.setFloat(prop, value);
				return true;
			}
			#else
			l.luaTrace("setShaderFloat: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			#end

			return false;
		});

		Lua_helper.set_static_callback("setShaderFloatArray", function(l:FunkinLua, obj:String, prop:String, values:Dynamic):Bool {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader != null) {
				shader.setFloatArray(prop, values);
				return true;
			}
			#else
			l.luaTrace("setShaderFloatArray: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			#end

			return false;
		});

		Lua_helper.set_static_callback("setShaderSampler2D", function(l:FunkinLua, obj:String, prop:String, bitmapdataPath:String):Bool {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader != null) {
				var value = Paths.image(bitmapdataPath);
				if (value == null || value.bitmap == null) return false;

				shader.setSampler2D(prop, value.bitmap);
				return true;
			}
			#else
			l.luaTrace("setShaderSampler2D: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			#end

			return false;
		});


		// luas shit
		Lua_helper.set_static_callback("getRunningScripts", function(_):Array<String> {
			var runningScripts:Array<String> = [];
			for (idx in 0...PlayState.instance.luaArray.length)
				runningScripts.push(PlayState.instance.luaArray[idx].scriptName);

			return runningScripts;
		});

		Lua_helper.set_static_callback("callOnLuas", function(l:FunkinLua, funcName:String, args:Array<Any>, ignoreStops:Bool = false, ignoreSelf:Bool = true, ?exclusions:Array<String>):Void {
			var scriptName:String = l.globalScriptName;

			if (ignoreSelf && !exclusions.contains(scriptName)) exclusions.push(scriptName);
			PlayState.instance.callOnLuas(funcName, args, ignoreStops, exclusions);
		});

		Lua_helper.set_static_callback("callScript", function(l:FunkinLua, luaFile:String, funcName:String, args:Array<Dynamic>):Dynamic {
			luaFile = format(luaFile);

			for (luaInstance in PlayState.instance.luaArray) {
				if (luaInstance.globalScriptName == luaFile && !luaInstance.closed)
					return luaInstance.call(funcName, args);
			}

			l.luaTrace('callScript: The script "${luaFile}" doesn\'t exists nor is active!');
			return null;
		});

		Lua_helper.set_static_callback("setGlobalFromScript", function(l:FunkinLua, luaFile:String, global:String, val:Dynamic):Bool {
			luaFile = format(luaFile);

			var got:Bool = false;
			for (luaInstance in PlayState.instance.luaArray) {
				if (luaInstance.globalScriptName == luaFile && !luaInstance.closed) {
					luaInstance.set(global, val);
					got = true;
				}
			}

			if (!got) {
				l.luaTrace('setGlobalFromScript: The script "${luaFile}" doesn\'t exists nor is active!');
				return false;
			}
			return true;
		});

		Lua_helper.set_static_callback("getGlobalFromScript", function(_, luaFile:String, global:String):Dynamic {
			luaFile = format(luaFile);

			for (luaInstance in PlayState.instance.luaArray) {
				if (luaInstance.globalScriptName == luaFile && !luaInstance.closed) {
					var lua:State = luaInstance.lua;
					Lua.getglobal(lua, global);

					var result:Dynamic = Convert.fromLua(lua, -1);
					Lua.pop(lua, 1);

					return result;
				}
			}
			return null;
		});

		Lua_helper.set_static_callback("addLuaScript", function(l:FunkinLua, luaFile:String, ?ignoreAlreadyRunning:Bool = false):Bool { //would be dope asf.
			luaFile = format(luaFile);

			if (!ignoreAlreadyRunning && PlayState.instance.isLuaRunning(luaFile)) {
				l.luaTrace('addLuaScript: The script "${luaFile}" is already running!');
				return false;
			}

			var res:FunkinLua = PlayState.instance.executeLua(luaFile);
			if (res == null) {
				l.luaTrace('addLuaScript: The script "${luaFile}" doesn\'t exist!', false, false, FlxColor.RED);
				return false;
			}
			return true;
		});

		Lua_helper.set_static_callback("removeLuaScript", function(l:FunkinLua, luaFile:String):Bool {
			luaFile = format(luaFile);

			var got:Bool = false;
			for (luaInstance in PlayState.instance.luaArray) {
				if (luaInstance.globalScriptName == luaFile && !luaInstance.closed) {
					luaInstance.closed = true;
					got = true;
				}
			}

			if (!got) {
				l.luaTrace('removeLuaScript: The script "${luaFile}" doesn\'t exists nor is active!');
				return false;
			}
			return true;
		});

		Lua_helper.set_static_callback("isRunning", function(_, luaFile:String):Bool {
			return PlayState.instance.isLuaRunning(luaFile);
		});

		Lua_helper.set_static_callback("close", function(l:FunkinLua):Bool {
			return l.closed = true;
		});

		Lua_helper.set_static_callback("parseHaxeCode", function(l:FunkinLua, code:String):Int {
			#if hscript
			try {
				return hscript.parse(code);
			}
			catch(e) {
				l.luaTrace(l.scriptName + ":" + l.lastCalledFunction + " - " + e, false, false, FlxColor.RED);
			}
			#else
			l.luaTrace("parseHaxeCode: HScript isn't supported on this platform!", false, false, FlxColor.RED);
			#end
			return -1;
		});

		Lua_helper.set_static_callback("runHaxeCode", function(l:FunkinLua, codeToRun:Dynamic):Dynamic {
			#if hscript
			try {
				var retVal:Dynamic;
				if (Std.isOfType(codeToRun, Int))
					retVal = hscript.execute(hscript.getExpr(codeToRun));
				else
					retVal = hscript.immediateExecute(codeToRun);

				if (retVal != null && isOfTypes(retVal, allowedHaxeTypes)) return retVal;
			}
			catch(e) {
				l.luaTrace(l.scriptName + ":" + l.lastCalledFunction + " - " + e, false, false, FlxColor.RED);
			}
			#else
			l.luaTrace("runHaxeCode: HScript isn't supported on this platform!", false, false, FlxColor.RED);
			#end

			return null;
		});

		Lua_helper.set_static_callback("addHaxeLibrary", function(l:FunkinLua, libName:String, ?libPackage:String):Void {
			#if hscript
			if (hscript.variables.exists(libName)) return;
			try {
				var str:String = '';
				if (libPackage != null && libPackage.length > 0)
					str = libPackage + '.';

				hscript.variables.set(libName, Type.resolveClass(str + libName));
			}
			catch (e:Dynamic) {
				l.luaTrace(l.scriptName + ":" + l.lastCalledFunction + " - " + e, false, false, FlxColor.RED);
			}
			#else
			l.luaTrace("addHaxeLibrary: HScript isn't supported on this platform!", false, false, FlxColor.RED);
			#end
		});


		// props
		Lua_helper.set_static_callback("getProperty", true, function(state:State, lua:FunkinLua):Int {
			if (!hasValidArgs(state, 1)) return 1;
			var variable:String = Convert.fromLua(state, 1);

			if ((variable is String)) {
				if (!Convert.toLua(state, getVarInstance(variable, false))) Lua.pushnil(state);
			}
			else {
				if (lua.getBool('luaBackwardCompatibility')) return Lua.gettop(state);
				Lua.pushnil(state);
			}

			return 1;
		});

		Lua_helper.set_static_callback("setProperty", true, function(state:State, lua:FunkinLua):Int {
			if (!hasValidArgs(state, 1)) return 1;
			var args = Lua.gettop(state), variable:String = Convert.fromLua(state, 1);

			if ((variable is String)) Lua.pushboolean(state, setVarInstance(variable, args > 1 ? Convert.fromLua(state, 2) : null));
			else Lua.pushboolean(state, false);

			return 1;
		});

		/*
		Lua_helper.set_static_callback("getPropertyAdvanced", function(_, varsStr:String) {
			var variables:Array<String> = varsStr.replace(' ', '').split(',');
			var leClass:Class<Dynamic> = Type.resolveClass(variables[0]);
			if(variables.length > 2) {
				var curProp:Dynamic = Reflect.getProperty(leClass, variables[1]);
				if(variables.length > 3) {
					for (i in 2...variables.length-1) {
						curProp = Reflect.getProperty(curProp, variables[i]);
					}
				}
				return Reflect.getProperty(curProp, variables[variables.length-1]);
			} else if(variables.length == 2) {
				return Reflect.getProperty(leClass, variables[variables.length-1]);
			}
			return null;
		});
		Lua_helper.set_static_callback("setPropertyAdvanced", function(_, varsStr:String, value:Dynamic) {
			var variables:Array<String> = varsStr.replace(' ', '').split(',');
			var leClass:Class<Dynamic> = Type.resolveClass(variables[0]);
			if(variables.length > 2) {
				var curProp:Dynamic = Reflect.getProperty(leClass, variables[1]);
				if(variables.length > 3) {
					for (i in 2...variables.length-1) {
						curProp = Reflect.getProperty(curProp, variables[i]);
					}
				}
				return Reflect.setProperty(curProp, variables[variables.length-1], value);
			} else if(variables.length == 2) {
				return Reflect.setProperty(leClass, variables[variables.length-1], value);
			}
		});
		*/

		Lua_helper.set_static_callback("getPropertyFromGroup", true, function(state:State, lua:FunkinLua):Int {
			if (!hasValidArgs(state, 3)) return 1;
			var obj:String = Convert.fromLua(state, 1), index:Int = Convert.fromLua(state, 2), variable:Dynamic = Convert.fromLua(state, 3);
			var realObject:Dynamic = getVarInstance(obj, false), isNull = false;

			if (Std.isOfType(realObject, FlxTypedGroup)) {
				if (!Convert.toLua(state, getGroupStuff(realObject.members[index], variable))) isNull = true;
			}
			else {
				var leArray:Dynamic = realObject[index];
				if (leArray != null) {
					var result:Dynamic = null;
					if ((variable is Int)) result = leArray[variable];
					else result = getGroupStuff(leArray, variable);

					if (!Convert.toLua(state, result)) isNull = true;
				}
				else {
					//lua.luaTrace("getPropertyFromGroup: Object #" + index + " from group: " + obj + " doesn't exist!", false, false, FlxColor.RED);
					Lua.pushnil(state);
				}
			}

			if (isNull) {
				if (lua.getBool('luaBackwardCompatibility')) return Lua.gettop(state);
				else Lua.pushnil(state);
			}
			return 1;
		});

		Lua_helper.set_static_callback("setPropertyFromGroup", true, function(state:State, lua:FunkinLua):Int {
			if (!hasValidArgs(state, 3)) return 1;
			var args = Lua.gettop(state);
			var obj:String = Convert.fromLua(state, 1), index:Int = Convert.fromLua(state, 2), variable:Dynamic = Convert.fromLua(state, 3);
			var value:Dynamic = args > 3 ? Convert.fromLua(state, 4) : null, realObject:Dynamic = getVarInstance(obj, false), isNull = false;

			if (Std.isOfType(realObject, FlxTypedGroup)) {
				setGroupStuff(realObject.members[index], variable, value);
				Lua.pushboolean(state, true);
			}
			else {
				var leArray:Dynamic = realObject[index];
				if (leArray != null) {
					if ((variable is Int)) leArray[variable] = value;
					else setGroupStuff(leArray, variable, value);
					Lua.pushboolean(state, true);
				}
				else Lua.pushboolean(state, false);
			}

			return 1;
		});

		Lua_helper.set_static_callback("removeFromGroup", true, function(state:State, lua:FunkinLua):Int {
			if (!hasValidArgs(state, 2)) return 1;
			var args = Lua.gettop(state);
			var obj:String = Convert.fromLua(state, 1), index:Int = Convert.fromLua(state, 2), dontDestroy:Bool = args > 2 ? Convert.fromLua(state, 3) : false;
			var grp:Dynamic = getVarInstance(obj, false);

			if (Std.isOfType(grp, FlxTypedGroup)) {
				var sex = grp.members[index];
				if (sex != null) {
					grp.remove(sex, true);
					if (!dontDestroy) {
						sex.kill();
						sex.destroy();
					}
				}
			}
			else grp.splice(index, 1);

			Lua.pushnil(state);
			return 1;
		});

		Lua_helper.set_static_callback("getPropertyFromClass", true, function(state:State, lua:FunkinLua):Int {
			if (!hasValidArgs(state, 2)) return 1;
			if (!Convert.toLua(state, getVarInObject(Type.resolveClass(Convert.fromLua(state, 1)), Convert.fromLua(state, 2))))
				Lua.pushnil(state);

			return 1;
		});

		Lua_helper.set_static_callback("setPropertyFromClass", true, function(state:State, lua:FunkinLua):Int {
			if (!hasValidArgs(state, 2)) return 1;
			var args:Int = Lua.gettop(state);
			Lua.pushboolean(state, setVarInObject(Type.resolveClass(Convert.fromLua(state, 1)), Convert.fromLua(state, 2), args > 2 ? Convert.fromLua(state, 3) : null));
			return 1;
		});


		// sprites
		Lua_helper.set_static_callback("makeLuaSprite", function(_, tag:String, image:String, x:Float, y:Float):Void {
			tag = tag.replace('.', '');
			resetSpriteTag(tag);

			var leSprite:ModchartSprite = new ModchartSprite(x, y);
			if (image != null && image.length > 0) leSprite.loadGraphic(Paths.image(image));
			leSprite.antialiasing = ClientPrefs.globalAntialiasing;

			PlayState.instance.modchartSprites.set(tag, leSprite);
		});

		Lua_helper.set_static_callback("makeAnimatedLuaSprite", function(_, tag:String, image:String, x:Float, y:Float, ?spriteType:String = "sparrow") {
			tag = tag.replace('.', '');
			resetSpriteTag(tag);

			var leSprite:ModchartSprite = new ModchartSprite(x, y);
			leSprite.antialiasing = ClientPrefs.globalAntialiasing;
			loadFrames(leSprite, image, spriteType);

			PlayState.instance.modchartSprites.set(tag, leSprite);
		});

		Lua_helper.set_static_callback("makeGraphic", function(_, obj:String, width:Int, height:Int, color:String):Bool {
			var spr:FlxSprite = getVarInstance(obj, true, false);

			if (spr == null) return false;
			var colorNum:Int = Std.parseInt((color.startsWith('0x')  ? '' : '0xff') + color);

			spr.makeGraphic(width, height, colorNum);
			return true;
		});

		Lua_helper.set_static_callback("addLuaSprite", function(_, tag:String, front:Bool = false):Bool {
			var shit:ModchartSprite = PlayState.instance.modchartSprites.get(tag);
			if (shit == null || shit.wasAdded) return false;

			if (front)
				getInstance().add(shit);
			else {
				if (PlayState.instance.isDead)
					GameOverSubstate.instance.insert(GameOverSubstate.instance.members.indexOf(GameOverSubstate.instance.boyfriend), shit);
				else {
					var position:Int = PlayState.instance.members.indexOf(PlayState.instance.gfGroup);
					if (PlayState.instance.members.indexOf(PlayState.instance.boyfriendGroup) < position)
						position = PlayState.instance.members.indexOf(PlayState.instance.boyfriendGroup);
					else if (PlayState.instance.members.indexOf(PlayState.instance.dadGroup) < position)
						position = PlayState.instance.members.indexOf(PlayState.instance.dadGroup);

					PlayState.instance.insert(position, shit);
				}
			}

			return shit.wasAdded = true;
		});

		Lua_helper.set_static_callback("removeLuaSprite", function(_, tag:String, destroy:Bool = true):Bool {
			var pee:ModchartSprite = PlayState.instance.modchartSprites.get(tag);
			if (pee == null) return false;

			if (destroy) pee.kill();
			if (pee.wasAdded) {
				getInstance().remove(pee, true);
				pee.wasAdded = false;
			}
			if (destroy) {
				pee.destroy();
				PlayState.instance.modchartSprites.remove(tag);
			}
			return true;
		});

		Lua_helper.set_static_callback("loadGraphic", function(_, variable:String, image:String, ?gridX:Int = 0, ?gridY:Int = 0):Bool {
			var spr:FlxSprite = getVarInstance(variable);

			if (spr == null || image == null || image.length <= 0) return false;
			var animated = gridX != 0 || gridY != 0;

			spr.loadGraphic(Paths.image(image), animated, gridX, gridY);
			return true;
		});

		Lua_helper.set_static_callback("loadFrames", function(_, variable:String, image:String, spriteType:String = "sparrow"):Bool {
			var spr:FlxSprite = getVarInstance(variable);
			if (spr == null || image == null || image.length <= 0) return false;

			loadFrames(spr, image, spriteType);
			return true;
		});

		Lua_helper.set_static_callback("setGraphicSize", function(_, obj:String, x:Int, y:Int = 0, updateHitbox:Bool = true):Bool {
			var poop:FlxSprite = getVarInstance(obj);
			if (poop == null) return false;

			poop.setGraphicSize(x, y);
			if (updateHitbox) poop.updateHitbox();
			return true;
		});

		Lua_helper.set_static_callback("scaleObject", function(_, obj:String, x:Float, y:Float, updateHitbox:Bool = true):Bool {
			var poop:FlxSprite = getVarInstance(obj);
			if (poop == null) return false;

			poop.scale.set(x, y);
			if (updateHitbox) poop.updateHitbox();
			return true;
		});

		Lua_helper.set_static_callback("getGraphicMidpointX", function(_, obj:String):Float {
			var spr:FlxSprite = getVarInstance(obj);
			if (spr != null) return spr.getGraphicMidpoint().x;
			return 0;
		});

		Lua_helper.set_static_callback("getGraphicMidpointY", function(_, obj:String):Float {
			var spr:FlxSprite = getVarInstance(obj);
			if (spr != null) return spr.getGraphicMidpoint().y;
			return 0;
		});

		Lua_helper.set_static_callback("updateHitbox", function(_, obj:String):Bool {
			var poop:FlxSprite = getVarInstance(obj);
			if (poop == null) return false;

			poop.updateHitbox();
			return true;
		});

		Lua_helper.set_static_callback("updateHitboxFromGroup", function(_, group:String, index:Int):Bool {
			var grp:Dynamic = getVarInstance(group, false);
			if (grp == null) return false;

			if (Std.isOfType(grp, FlxTypedGroup))
				grp.members[index].updateHitbox();
			else
				grp[index].updateHitbox();

			return true;
		});

		Lua_helper.set_static_callback("screenCenter", function(_, obj:String, pos:String = 'xy'):Bool {
			var spr:FlxSprite = getVarInstance(obj);
			if (spr == null) return false;

			switch(pos.trim().toLowerCase()) {
				case 'x': spr.screenCenter(X);
				case 'y': spr.screenCenter(Y);
				default: spr.screenCenter(XY);
			}
			return true;
		});

		Lua_helper.set_static_callback("setBlendMode", function(l:FunkinLua, obj:String, blend:String = ''):Bool {
			var spr:FlxSprite = getVarInstance(obj);
			if (spr == null) return false;

			spr.blend = blendModeFromString(blend);
			return true;
		});

		Lua_helper.set_static_callback("getPixelColor", function(_, obj:String, x:Int, y:Int):Int {
			var spr:FlxSprite = getVarInstance(obj);
			if (spr == null) return 0;

			if (spr.framePixels != null) return spr.framePixels.getPixel32(x, y);
			return spr.pixels.getPixel32(x, y);
		});


		// objects
		Lua_helper.set_static_callback("luaSpriteExists", function(_, tag:String):Bool {
			return PlayState.instance.modchartSprites.exists(tag);
		});

		Lua_helper.set_static_callback("luaTextExists", function(_, tag:String):Bool {
			return PlayState.instance.modchartTexts.exists(tag);
		});

		Lua_helper.set_static_callback("luaSoundExists", function(_, tag:String):Bool {
			return PlayState.instance.modchartSounds.exists(tag);
		});

		Lua_helper.set_static_callback("setScrollFactor", function(_, obj:String, scrollX:Float, scrollY:Float):Bool {
			var obj:FlxObject = getVarInstance(obj);
			if (obj == null) return false;

			obj.scrollFactor.set(scrollX, scrollY);
			return true;
		});

		Lua_helper.set_static_callback("getMidpointX", function(_, obj:String):Float {
			var obj:FlxObject = getVarInstance(obj);
			if (obj != null) return obj.getMidpoint().x;
			return 0;
		});

		Lua_helper.set_static_callback("getMidpointY", function(_, obj:String):Float {
			var obj:FlxObject = getVarInstance(obj);
			if (obj != null) return obj.getMidpoint().y;
			return 0;
		});

		Lua_helper.set_static_callback("getScreenPositionX", function(_, obj:String):Float {
			var poop:FlxObject = getVarInstance(obj);
			if (poop != null) return poop.getScreenPosition().x;
			return 0;
		});

		Lua_helper.set_static_callback("getScreenPositionY", function(_, obj:String):Float {
			var poop:FlxObject = getVarInstance(obj);
			if (poop != null) return poop.getScreenPosition().y;
			return 0;
		});

		Lua_helper.set_static_callback("objectsOverlap", function(_, obj1:String, obj2:String):Bool {
			var guh1:FlxBasic = getVarInstance(obj1), guh2:FlxBasic = getVarInstance(obj2);
			if (guh1 == null || guh2 == null) return false;
			return FlxG.overlap(guh1, guh2);
		});

		Lua_helper.set_static_callback("setObjectCamera", function(_, obj:String, camera:String = ''):Bool {
			var poop:FlxBasic = getVarInstance(obj);
			if (poop == null) return false;

			poop.cameras = [cameraFromString(camera)];
			return true;
		});

		//shitass stuff for epic coders like me B)  *image of obama giving himself a medal*
		Lua_helper.set_static_callback("getObjectOrder", function(_, obj:String):Int {
			var poop:FlxBasic = getVarInstance(obj);
			if (poop != null) return getInstance().members.indexOf(poop);
			return -1;
		});

		Lua_helper.set_static_callback("setObjectOrder", function(_, obj:String, order:Int):Bool {
			var poop:FlxBasic = getVarInstance(obj);
			if (poop == null) return false;

			getInstance().remove(poop, true);
			getInstance().insert(order, poop);
			return true;
		});


		// animations
		Lua_helper.set_static_callback("addAnimationByPrefix", function(_, obj:String, name:String, prefix:String, framerate:Int = 24, loop:Bool = true) {
			if(PlayState.instance.getLuaObject(obj,false)!=null) {
				var cock:FlxSprite = PlayState.instance.getLuaObject(obj,false);
				cock.animation.addByPrefix(name, prefix, framerate, loop);
				if(cock.animation.curAnim == null) {
					cock.animation.play(name, true);
				}
				return;
			}

			var cock:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if(cock != null) {
				cock.animation.addByPrefix(name, prefix, framerate, loop);
				if(cock.animation.curAnim == null) {
					cock.animation.play(name, true);
				}
			}
		});

		Lua_helper.set_static_callback("addAnimation", function(_, obj:String, name:String, frames:Array<Int>, framerate:Int = 24, loop:Bool = true) {
			if(PlayState.instance.getLuaObject(obj,false)!=null) {
				var cock:FlxSprite = PlayState.instance.getLuaObject(obj,false);
				cock.animation.add(name, frames, framerate, loop);
				if(cock.animation.curAnim == null) {
					cock.animation.play(name, true);
				}
				return;
			}

			var cock:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if(cock != null) {
				cock.animation.add(name, frames, framerate, loop);
				if(cock.animation.curAnim == null) {
					cock.animation.play(name, true);
				}
			}
		});

		Lua_helper.set_static_callback("addAnimationByIndices", function(_, obj:String, name:String, prefix:String, indices:String, framerate:Int = 24) {
			return addAnimByIndices(obj, name, prefix, indices, framerate, false);
		});

		Lua_helper.set_static_callback("addAnimationByIndicesLoop", function(_, obj:String, name:String, prefix:String, indices:String, framerate:Int = 24) {
			return addAnimByIndices(obj, name, prefix, indices, framerate, true);
		});

		Lua_helper.set_static_callback("playAnim", function(_, obj:String, name:String, forced:Bool = false, ?reverse:Bool = false, ?startFrame:Int = 0)
		{
			if(PlayState.instance.getLuaObject(obj, false) != null) {
				var luaObj:FlxSprite = PlayState.instance.getLuaObject(obj,false);
				if(luaObj.animation.getByName(name) != null)
				{
					luaObj.animation.play(name, forced, reverse, startFrame);
					if(Std.isOfType(luaObj, ModchartSprite))
					{
						//convert luaObj to ModchartSprite
						var obj:Dynamic = luaObj;
						var luaObj:ModchartSprite = obj;

						var daOffset = luaObj.animOffsets.get(name);
						if (luaObj.animOffsets.exists(name))
						{
							luaObj.offset.set(daOffset[0], daOffset[1]);
						}
					}
				}
				return true;
			}

			var spr:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if(spr != null) {
				if(spr.animation.getByName(name) != null)
				{
					if(Std.isOfType(spr, Character))
					{
						//convert spr to Character
						var obj:Dynamic = spr;
						var spr:Character = obj;
						spr.playAnim(name, forced, reverse, startFrame);
					}
					else
						spr.animation.play(name, forced, reverse, startFrame);
				}
				return true;
			}
			return false;
		});

		Lua_helper.set_static_callback("addOffset", function(_, obj:String, anim:String, x:Float, y:Float) {
			if(PlayState.instance.modchartSprites.exists(obj)) {
				PlayState.instance.modchartSprites.get(obj).animOffsets.set(anim, [x, y]);
				return true;
			}

			var char:Character = Reflect.getProperty(getInstance(), obj);
			if(char != null) {
				char.addOffset(anim, x, y);
				return true;
			}
			return false;
		});


		// gay ass tweens
		Lua_helper.set_static_callback("doTweenX", function(l:FunkinLua, tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = tweenShit(tag, vars);
			if(penisExam != null) {
				PlayState.instance.modchartTweens.set(tag, FlxTween.tween(penisExam, {x: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			} else {
				l.luaTrace('doTweenX: Couldnt find object: ' + vars, false, false, FlxColor.RED);
			}
		});
		Lua_helper.set_static_callback("doTweenY", function(l:FunkinLua, tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = tweenShit(tag, vars);
			if(penisExam != null) {
				PlayState.instance.modchartTweens.set(tag, FlxTween.tween(penisExam, {y: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			} else {
				l.luaTrace('doTweenY: Couldnt find object: ' + vars, false, false, FlxColor.RED);
			}
		});
		Lua_helper.set_static_callback("doTweenAngle", function(l:FunkinLua, tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = tweenShit(tag, vars);
			if(penisExam != null) {
				PlayState.instance.modchartTweens.set(tag, FlxTween.tween(penisExam, {angle: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			} else {
				l.luaTrace('doTweenAngle: Couldnt find object: ' + vars, false, false, FlxColor.RED);
			}
		});
		Lua_helper.set_static_callback("doTweenAlpha", function(l:FunkinLua, tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = tweenShit(tag, vars);
			if(penisExam != null) {
				PlayState.instance.modchartTweens.set(tag, FlxTween.tween(penisExam, {alpha: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			} else {
				l.luaTrace('doTweenAlpha: Couldnt find object: ' + vars, false, false, FlxColor.RED);
			}
		});
		Lua_helper.set_static_callback("doTweenZoom", function(l:FunkinLua, tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = tweenShit(tag, vars);
			if(penisExam != null) {
				PlayState.instance.modchartTweens.set(tag, FlxTween.tween(penisExam, {zoom: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			} else {
				l.luaTrace('doTweenZoom: Couldnt find object: ' + vars, false, false, FlxColor.RED);
			}
		});
		Lua_helper.set_static_callback("doTweenColor", function(l:FunkinLua, tag:String, vars:String, targetColor:String, duration:Float, ease:String) {
			var penisExam:Dynamic = tweenShit(tag, vars);
			if(penisExam != null) {
				var color:Int = Std.parseInt(targetColor);
				if(!targetColor.startsWith('0x')) color = Std.parseInt('0xff' + targetColor);

				var curColor:FlxColor = penisExam.color;
				curColor.alphaFloat = penisExam.alpha;
				PlayState.instance.modchartTweens.set(tag, FlxTween.color(penisExam, duration, curColor, color, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.modchartTweens.remove(tag);
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
					}
				}));
			} else {
				l.luaTrace('doTweenColor: Couldnt find object: ' + vars, false, false, FlxColor.RED);
			}
		});

		//Tween shit, but for strums
		Lua_helper.set_static_callback("noteTweenX", function(_, tag:String, note:Int, value:Dynamic, duration:Float, ease:String) {
			cancelTween(tag);
			if(note < 0) note = 0;
			var testicle:StrumNote = PlayState.instance.strumLineNotes.members[note % PlayState.instance.strumLineNotes.length];

			if(testicle != null) {
				PlayState.instance.modchartTweens.set(tag, FlxTween.tween(testicle, {x: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			}
		});
		Lua_helper.set_static_callback("noteTweenY", function(_, tag:String, note:Int, value:Dynamic, duration:Float, ease:String) {
			cancelTween(tag);
			if(note < 0) note = 0;
			var testicle:StrumNote = PlayState.instance.strumLineNotes.members[note % PlayState.instance.strumLineNotes.length];

			if(testicle != null) {
				PlayState.instance.modchartTweens.set(tag, FlxTween.tween(testicle, {y: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			}
		});
		Lua_helper.set_static_callback("noteTweenAngle", function(_, tag:String, note:Int, value:Dynamic, duration:Float, ease:String) {
			cancelTween(tag);
			if(note < 0) note = 0;
			var testicle:StrumNote = PlayState.instance.strumLineNotes.members[note % PlayState.instance.strumLineNotes.length];

			if(testicle != null) {
				PlayState.instance.modchartTweens.set(tag, FlxTween.tween(testicle, {angle: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			}
		});
		Lua_helper.set_static_callback("noteTweenDirection", function(_, tag:String, note:Int, value:Dynamic, duration:Float, ease:String) {
			cancelTween(tag);
			if(note < 0) note = 0;
			var testicle:StrumNote = PlayState.instance.strumLineNotes.members[note % PlayState.instance.strumLineNotes.length];

			if(testicle != null) {
				PlayState.instance.modchartTweens.set(tag, FlxTween.tween(testicle, {direction: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			}
		});
		Lua_helper.set_static_callback("noteTweenAngle", function(_, tag:String, note:Int, value:Dynamic, duration:Float, ease:String) {
			cancelTween(tag);
			if(note < 0) note = 0;
			var testicle:StrumNote = PlayState.instance.strumLineNotes.members[note % PlayState.instance.strumLineNotes.length];

			if(testicle != null) {
				PlayState.instance.modchartTweens.set(tag, FlxTween.tween(testicle, {angle: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			}
		});
		Lua_helper.set_static_callback("noteTweenAlpha", function(_, tag:String, note:Int, value:Dynamic, duration:Float, ease:String) {
			cancelTween(tag);
			if(note < 0) note = 0;
			var testicle:StrumNote = PlayState.instance.strumLineNotes.members[note % PlayState.instance.strumLineNotes.length];

			if(testicle != null) {
				PlayState.instance.modchartTweens.set(tag, FlxTween.tween(testicle, {alpha: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			}
		});


		// timer n tweens
		Lua_helper.set_static_callback("cancelTween", function(_, tag:String) {
			cancelTween(tag);
		});

		Lua_helper.set_static_callback("runTimer", function(_, tag:String, time:Float = 1, loops:Int = 1) {
			cancelTimer(tag);
			PlayState.instance.modchartTimers.set(tag, new FlxTimer().start(time, function(tmr:FlxTimer) {
				if(tmr.finished)
					PlayState.instance.modchartTimers.remove(tag);

				PlayState.instance.callOnLuas('onTimerCompleted', [tag, tmr.loops, tmr.loopsLeft]);
				//trace('Timer Completed: ' + tag);
			}, loops));
		});

		Lua_helper.set_static_callback("cancelTimer", function(_, tag:String) {
			cancelTimer(tag);
		});


		// cameras
		Lua_helper.set_static_callback("cameraSetTarget", function(_, target:String) {
			var isDad:Bool = target == 'dad';
			PlayState.instance.moveCamera(isDad);
			return isDad;
		});

		Lua_helper.set_static_callback("cameraShake", function(_, camera:String, intensity:Float, duration:Float) {
			cameraFromString(camera).shake(intensity, duration);
		});

		Lua_helper.set_static_callback("cameraFlash", function(_, camera:String, color:String, duration:Float,forced:Bool) {
			var colorNum:Int = Std.parseInt(color);
			if(!color.startsWith('0x')) colorNum = Std.parseInt('0xff' + color);
			cameraFromString(camera).flash(colorNum, duration,null,forced);
		});

		Lua_helper.set_static_callback("cameraFade", function(_, camera:String, color:String, duration:Float,forced:Bool) {
			var colorNum:Int = Std.parseInt(color);
			if(!color.startsWith('0x')) colorNum = Std.parseInt('0xff' + color);
			cameraFromString(camera).fade(colorNum, duration,false,null,forced);
		});


		// Gamplay
		Lua_helper.set_static_callback("loadSong", function(_, ?name:String = null, ?difficultyNum:Int = -1) {
			if(name == null || name.length <= 0) name = PlayState.SONG.song;
			if (difficultyNum == -1) difficultyNum = PlayState.storyDifficulty;

			var poop = Highscore.formatSong(name, difficultyNum);
			PlayState.SONG = Song.loadFromJson(poop, name);
			PlayState.storyDifficulty = difficultyNum;
			PlayState.instance.persistentUpdate = false;
			LoadingState.loadAndSwitchState(new PlayState());

			FlxG.sound.music.pause();
			FlxG.sound.music.volume = 0;
			if(PlayState.instance.vocals != null) {
				PlayState.instance.vocals.pause();
				PlayState.instance.vocals.volume = 0;
			}
		});

		Lua_helper.set_static_callback("generateStaticArrows", function(_, player:Int, arrowTweens:Bool = false) {
			PlayState.instance.generateStaticArrows(player, arrowTweens);
			return true;
		});

		Lua_helper.set_static_callback("startCountdown", function() {
			PlayState.instance.startCountdown();
			return true;
		});

		Lua_helper.set_static_callback("endSong", function() {
			PlayState.instance.KillNotes();
			PlayState.instance.endSong();
			return true;
		});

		Lua_helper.set_static_callback("restartSong", function(_, ?skipTransition:Bool = false) {
			PlayState.instance.persistentUpdate = false;
			PauseSubState.restartSong(skipTransition);
			return true;
		});

		Lua_helper.set_static_callback("exitSong", function(_, ?skipTransition:Bool = false) {
			if(skipTransition) {
				FlxTransitionableState.skipNextTransIn = true;
				FlxTransitionableState.skipNextTransOut = true;
			}

			PlayState.cancelMusicFadeTween();
			CustomFadeTransition.nextCamera = PlayState.instance.camOther;
			if(FlxTransitionableState.skipNextTransIn)
				CustomFadeTransition.nextCamera = null;

			if(PlayState.isStoryMode)
				MusicBeatState.switchState(new StoryMenuState());
			else
				MusicBeatState.switchState(new FreeplayState());

			FlxG.sound.playMusic(Paths.music('freakyMenu'));
			PlayState.changedDifficulty = false;
			PlayState.chartingMode = false;
			PlayState.instance.transitioning = true;
			WeekData.loadTheFirstEnabledMod();
			return true;
		});

		Lua_helper.set_static_callback("getSongPosition", function() {
			return Conductor.songPosition;
		});

		Lua_helper.set_static_callback("triggerEvent", function(_, name:String, value1:String, value2:String) {
			PlayState.instance.triggerEventNote(name, value1, value2);
			return true;
		});

		Lua_helper.set_static_callback("addScore", function(_, value:Int = 0) {
			PlayState.instance.songScore += value;
			PlayState.instance.RecalculateRating();
		});

		Lua_helper.set_static_callback("addMisses", function(_, value:Int = 0) {
			PlayState.instance.songMisses += value;
			PlayState.instance.RecalculateRating();
		});

		Lua_helper.set_static_callback("addHits", function(_, value:Int = 0) {
			PlayState.instance.songHits += value;
			PlayState.instance.RecalculateRating();
		});

		Lua_helper.set_static_callback("setScore", function(_, value:Int = 0) {
			PlayState.instance.songScore = value;
			PlayState.instance.RecalculateRating();
		});

		Lua_helper.set_static_callback("setMisses", function(_, value:Int = 0) {
			PlayState.instance.songMisses = value;
			PlayState.instance.RecalculateRating();
		});

		Lua_helper.set_static_callback("setHits", function(_, value:Int = 0) {
			PlayState.instance.songHits = value;
			PlayState.instance.RecalculateRating();
		});

		Lua_helper.set_static_callback("getScore", function() {
			return PlayState.instance.songScore;
		});

		Lua_helper.set_static_callback("getMisses", function() {
			return PlayState.instance.songMisses;
		});
		Lua_helper.set_static_callback("getHits", function() {
			return PlayState.instance.songHits;
		});

		Lua_helper.set_static_callback("setHealth", function(_, value:Float = 0) {
			PlayState.instance.health = value;
		});

		Lua_helper.set_static_callback("addHealth", function(_, value:Float = 0) {
			PlayState.instance.health += value;
		});

		Lua_helper.set_static_callback("getHealth", function() {
			return PlayState.instance.health;
		});

		Lua_helper.set_static_callback("setRatingPercent", function(_, value:Float) {
			PlayState.instance.ratingPercent = value;
		});

		Lua_helper.set_static_callback("setRatingName", function(_, value:String) {
			PlayState.instance.ratingName = value;
		});

		Lua_helper.set_static_callback("setRatingFC", function(_, value:String) {
			PlayState.instance.ratingFC = value;
		});

		Lua_helper.set_static_callback("setHealthBarColors", function(_, leftHex:String, rightHex:String) {
			var left:FlxColor = Std.parseInt(leftHex);
			if(!leftHex.startsWith('0x')) left = Std.parseInt('0xff' + leftHex);
			var right:FlxColor = Std.parseInt(rightHex);
			if(!rightHex.startsWith('0x')) right = Std.parseInt('0xff' + rightHex);

			PlayState.instance.healthBar.createFilledBar(left, right);
			PlayState.instance.healthBar.updateBar();
		});

		Lua_helper.set_static_callback("setTimeBarColors", function(_, leftHex:String, rightHex:String) {
			var left:FlxColor = Std.parseInt(leftHex);
			if(!leftHex.startsWith('0x')) left = Std.parseInt('0xff' + leftHex);
			var right:FlxColor = Std.parseInt(rightHex);
			if(!rightHex.startsWith('0x')) right = Std.parseInt('0xff' + rightHex);

			PlayState.instance.timeBar.createFilledBar(right, left);
			PlayState.instance.timeBar.updateBar();
		});

		Lua_helper.set_static_callback("startDialogue", function(l:FunkinLua, dialogueFile:String, music:String = null) {
			var path:String;
			#if MODS_ALLOWED
			path = Paths.modsJson(Paths.formatToSongPath(PlayState.SONG.song) + '/' + dialogueFile);
			if(!FileSystem.exists(path))
			#end
				path = Paths.json(Paths.formatToSongPath(PlayState.SONG.song) + '/' + dialogueFile);

			l.luaTrace('startDialogue: Trying to load dialogue: ' + path);

			#if MODS_ALLOWED
			if(FileSystem.exists(path))
			#else
			if(Assets.exists(path))
			#end {
				var shit:DialogueFile = DialogueBoxPsych.parseDialogue(path);
				if(shit.dialogue.length > 0) {
					PlayState.instance.startDialogue(shit, music);
					l.luaTrace('startDialogue: Successfully loaded dialogue', false, false, FlxColor.GREEN);
					return true;
				} else
					l.luaTrace('startDialogue: Your dialogue file is badly formatted!', false, false, FlxColor.RED);
			}
			else {
				l.luaTrace('startDialogue: Dialogue file not found', false, false, FlxColor.RED);
				if(PlayState.instance.endingSong)
					PlayState.instance.endSong();
				else
					PlayState.instance.startCountdown();
			}
			return false;
		});
		Lua_helper.set_static_callback("startVideo", function(l:FunkinLua, videoFile:String) {
			#if VIDEOS_ALLOWED
			if(FileSystem.exists(Paths.video(videoFile))) {
				PlayState.instance.startVideo(videoFile);
				return true;
			}

			l.luaTrace('startVideo: Video file not found: ' + videoFile, false, false, FlxColor.RED);
			return false;
			#else
			if(PlayState.instance.endingSong)
				PlayState.instance.endSong();
			else
				PlayState.instance.startCountdown();

			return true;
			#end
		});


		// controls
		Lua_helper.set_static_callback("keyboardJustPressed", function(_, name:String) {
			return Reflect.getProperty(FlxG.keys.justPressed, name);
		});
		Lua_helper.set_static_callback("keyboardPressed", function(_, name:String) {
			return Reflect.getProperty(FlxG.keys.pressed, name);
		});
		Lua_helper.set_static_callback("keyboardReleased", function(_, name:String) {
			return Reflect.getProperty(FlxG.keys.justReleased, name);
		});

		Lua_helper.set_static_callback("anyGamepadJustPressed", function(_, name:String) {
			return FlxG.gamepads.anyJustPressed(name);
		});
		Lua_helper.set_static_callback("anyGamepadPressed", function(_, name:String) {
			return FlxG.gamepads.anyPressed(name);
		});
		Lua_helper.set_static_callback("anyGamepadReleased", function(_, name:String) {
			return FlxG.gamepads.anyJustReleased(name);
		});

		Lua_helper.set_static_callback("gamepadAnalogX", function(_, id:Int, ?leftStick:Bool = true) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null)
			{
				return 0.0;
			}
			return controller.getXAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		Lua_helper.set_static_callback("gamepadAnalogY", function(_, id:Int, ?leftStick:Bool = true) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null)
			{
				return 0.0;
			}
			return controller.getYAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		Lua_helper.set_static_callback("gamepadJustPressed", function(_, id:Int, name:String) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null)
			{
				return false;
			}
			return Reflect.getProperty(controller.justPressed, name) == true;
		});
		Lua_helper.set_static_callback("gamepadPressed", function(_, id:Int, name:String) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null)
			{
				return false;
			}
			return Reflect.getProperty(controller.pressed, name) == true;
		});
		Lua_helper.set_static_callback("gamepadReleased", function(_, id:Int, name:String) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null)
			{
				return false;
			}
			return Reflect.getProperty(controller.justReleased, name) == true;
		});

		Lua_helper.set_static_callback("keyJustPressed", function(_, name:String) {
			var key:Bool = false;
			switch(name) {
				case 'left': key = PlayState.instance.getControl('NOTE_LEFT_P');
				case 'down': key = PlayState.instance.getControl('NOTE_DOWN_P');
				case 'up': key = PlayState.instance.getControl('NOTE_UP_P');
				case 'right': key = PlayState.instance.getControl('NOTE_RIGHT_P');
				case 'accept': key = PlayState.instance.getControl('ACCEPT');
				case 'back': key = PlayState.instance.getControl('BACK');
				case 'pause': key = PlayState.instance.getControl('PAUSE');
				case 'reset': key = PlayState.instance.getControl('RESET');
				case 'space': key = FlxG.keys.justPressed.SPACE;//an extra key for convinience
			}
			return key;
		});
		Lua_helper.set_static_callback("keyPressed", function(_, name:String) {
			var key:Bool = false;
			switch(name) {
				case 'left': key = PlayState.instance.getControl('NOTE_LEFT');
				case 'down': key = PlayState.instance.getControl('NOTE_DOWN');
				case 'up': key = PlayState.instance.getControl('NOTE_UP');
				case 'right': key = PlayState.instance.getControl('NOTE_RIGHT');
				case 'space': key = FlxG.keys.pressed.SPACE;//an extra key for convinience
			}
			return key;
		});
		Lua_helper.set_static_callback("keyReleased", function(_, name:String) {
			var key:Bool = false;
			switch(name) {
				case 'left': key = PlayState.instance.getControl('NOTE_LEFT_R');
				case 'down': key = PlayState.instance.getControl('NOTE_DOWN_R');
				case 'up': key = PlayState.instance.getControl('NOTE_UP_R');
				case 'right': key = PlayState.instance.getControl('NOTE_RIGHT_R');
				case 'space': key = FlxG.keys.justReleased.SPACE;//an extra key for convinience
			}
			return key;
		});

		Lua_helper.set_static_callback("getMouseX", function(_, camera:String) {
			var cam:FlxCamera = cameraFromString(camera);
			return FlxG.mouse.getScreenPosition(cam).x;
		});
		Lua_helper.set_static_callback("getMouseY", function(_, camera:String) {
			var cam:FlxCamera = cameraFromString(camera);
			return FlxG.mouse.getScreenPosition(cam).y;
		});

		Lua_helper.set_static_callback("mouseClicked", function(_, button:String) {
			return switch(button.trim().toLowerCase()) {
				case 'middle': FlxG.mouse.justPressedMiddle;
				case 'right': FlxG.mouse.justPressedRight;
				default: FlxG.mouse.justPressed;
			}
		});

		Lua_helper.set_static_callback("mousePressed", function(_, button:String) {
			return switch(button.trim().toLowerCase()) {
				case 'middle': FlxG.mouse.pressedMiddle;
				case 'right': FlxG.mouse.pressedRight;
				default: FlxG.mouse.pressed;
			}
		});

		Lua_helper.set_static_callback("mouseReleased", function(_, button:String) {
			return switch(button.trim().toLowerCase()) {
				case 'middle': FlxG.mouse.justReleasedMiddle;
				case 'right': FlxG.mouse.justReleased;
				default: FlxG.mouse.justReleased;
			}
		});


		// characters
		Lua_helper.set_static_callback("getCharacterX", function(_, type:String) {
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent':
					return PlayState.instance.dadGroup.x;
				case 'gf' | 'girlfriend':
					return PlayState.instance.gfGroup.x;
				default:
					return PlayState.instance.boyfriendGroup.x;
			}
		});

		Lua_helper.set_static_callback("setCharacterX", function(_, type:String, value:Float) {
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent':
					PlayState.instance.dadGroup.x = value;
				case 'gf' | 'girlfriend':
					PlayState.instance.gfGroup.x = value;
				default:
					PlayState.instance.boyfriendGroup.x = value;
			}
		});

		Lua_helper.set_static_callback("getCharacterY", function(_, type:String) {
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent':
					return PlayState.instance.dadGroup.y;
				case 'gf' | 'girlfriend':
					return PlayState.instance.gfGroup.y;
				default:
					return PlayState.instance.boyfriendGroup.y;
			}
		});

		Lua_helper.set_static_callback("setCharacterY", function(_, type:String, value:Float) {
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent':
					PlayState.instance.dadGroup.y = value;
				case 'gf' | 'girlfriend':
					PlayState.instance.gfGroup.y = value;
				default:
					PlayState.instance.boyfriendGroup.y = value;
			}
		});

		Lua_helper.set_static_callback("characterDance", function(_, character:String) {
			switch(character.toLowerCase()) {
				case 'dad': PlayState.instance.dad.dance();
				case 'gf' | 'girlfriend': if(PlayState.instance.gf != null) PlayState.instance.gf.dance();
				default: PlayState.instance.boyfriend.dance();
			}
		});


		// ssounds
		Lua_helper.set_static_callback("playMusic", function(_, sound:String, volume:Float = 1, loop:Bool = false) {
			FlxG.sound.playMusic(Paths.music(sound), volume, loop);
		});

		Lua_helper.set_static_callback("playSound", function(_, sound:String, volume:Float = 1, ?tag:String = null) {
			if(tag != null && tag.length > 0) {
				tag = tag.replace('.', '');
				if(PlayState.instance.modchartSounds.exists(tag)) {
					PlayState.instance.modchartSounds.get(tag).stop();
				}
				PlayState.instance.modchartSounds.set(tag, FlxG.sound.play(Paths.sound(sound), volume, false, function() {
					PlayState.instance.modchartSounds.remove(tag);
					PlayState.instance.callOnLuas('onSoundFinished', [tag]);
				}));
				return;
			}
			FlxG.sound.play(Paths.sound(sound), volume);
		});

		Lua_helper.set_static_callback("stopSound", function(_, tag:String) {
			if(tag != null && tag.length > 1 && PlayState.instance.modchartSounds.exists(tag)) {
				PlayState.instance.modchartSounds.get(tag).stop();
				PlayState.instance.modchartSounds.remove(tag);
			}
		});

		Lua_helper.set_static_callback("pauseSound", function(_, tag:String) {
			if(tag != null && tag.length > 1 && PlayState.instance.modchartSounds.exists(tag)) {
				PlayState.instance.modchartSounds.get(tag).pause();
			}
		});

		Lua_helper.set_static_callback("resumeSound", function(_, tag:String) {
			if(tag != null && tag.length > 1 && PlayState.instance.modchartSounds.exists(tag)) {
				PlayState.instance.modchartSounds.get(tag).play();
			}
		});

		Lua_helper.set_static_callback("soundFadeIn", function(_, tag:String, duration:Float, fromValue:Float = 0, toValue:Float = 1) {
			if(tag == null || tag.length < 1) {
				FlxG.sound.music.fadeIn(duration, fromValue, toValue);
			} else if(PlayState.instance.modchartSounds.exists(tag)) {
				PlayState.instance.modchartSounds.get(tag).fadeIn(duration, fromValue, toValue);
			}

		});

		Lua_helper.set_static_callback("soundFadeOut", function(_, tag:String, duration:Float, toValue:Float = 0) {
			if(tag == null || tag.length < 1) {
				FlxG.sound.music.fadeOut(duration, toValue);
			} else if(PlayState.instance.modchartSounds.exists(tag)) {
				PlayState.instance.modchartSounds.get(tag).fadeOut(duration, toValue);
			}
		});

		Lua_helper.set_static_callback("soundFadeCancel", function(_, tag:String) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music.fadeTween != null) {
					FlxG.sound.music.fadeTween.cancel();
				}
			} else if(PlayState.instance.modchartSounds.exists(tag)) {
				var theSound:FlxSound = PlayState.instance.modchartSounds.get(tag);
				if(theSound.fadeTween != null) {
					theSound.fadeTween.cancel();
					PlayState.instance.modchartSounds.remove(tag);
				}
			}
		});

		Lua_helper.set_static_callback("getSoundVolume", function(_, tag:String) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) {
					return FlxG.sound.music.volume;
				}
			} else if(PlayState.instance.modchartSounds.exists(tag)) {
				return PlayState.instance.modchartSounds.get(tag).volume;
			}
			return 0;
		});

		Lua_helper.set_static_callback("setSoundVolume", function(_, tag:String, value:Float) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) {
					FlxG.sound.music.volume = value;
				}
			} else if(PlayState.instance.modchartSounds.exists(tag)) {
				PlayState.instance.modchartSounds.get(tag).volume = value;
			}
		});

		Lua_helper.set_static_callback("getSoundTime", function(_, tag:String) {
			if(tag != null && tag.length > 0 && PlayState.instance.modchartSounds.exists(tag))
				return PlayState.instance.modchartSounds.get(tag).time;
			return 0;
		});

		Lua_helper.set_static_callback("setSoundTime", function(_, tag:String, value:Float) {
			if(tag != null && tag.length > 0 && PlayState.instance.modchartSounds.exists(tag)) {
				var theSound:FlxSound = PlayState.instance.modchartSounds.get(tag);
				if(theSound != null)
					//var wasResumed:Bool = theSound.playing;
					//theSound.pause();
					theSound.time = value;
					//if(wasResumed) theSound.play();
			}
		});

		Lua_helper.set_static_callback("getSoundPitch", function(_, tag:String) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null)
					return FlxG.sound.music.pitch;
			}
			else if (PlayState.instance.modchartSounds.exists(tag))
				return PlayState.instance.modchartSounds.get(tag).pitch;
			
			return 1;
		});

		Lua_helper.set_static_callback("setSoundPitch", function(_, tag:String, value:Float = 1) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null)
					FlxG.sound.music.pitch = value;
			}
			else if (PlayState.instance.modchartSounds.exists(tag)) {
				var theSound:FlxSound = PlayState.instance.modchartSounds.get(tag);
				if(theSound != null) {
					theSound.pitch = value;
				}
			}
		});


		// precaching
		Lua_helper.set_static_callback("addCharacterToList", function(_, name:String, type:String) {
			var charType:Int = 0;
			switch(type.toLowerCase()) {
				case 'dad': charType = 1;
				case 'gf' | 'girlfriend': charType = 2;
			}
			PlayState.instance.addCharacterToList(name, charType);
		});
		Lua_helper.set_static_callback("precacheImage", function(_, name:String) {
			Paths.returnGraphic(name);
		});
		Lua_helper.set_static_callback("precacheSound", function(_, name:String) {
			Paths.sound(name);
		});
		Lua_helper.set_static_callback("precacheMusic", function(_, name:String) {
			Paths.music(name);
		});


		// LUA TEXTS
		Lua_helper.set_static_callback("makeLuaText", function(_, tag:String, text:String, width:Int, x:Float, y:Float) {
			tag = tag.replace('.', '');
			resetTextTag(tag);
			PlayState.instance.modchartTexts.set(tag, new ModchartText(x, y, text, width));
		});

		Lua_helper.set_static_callback("addLuaText", function(_, tag:String) {
			if(PlayState.instance.modchartTexts.exists(tag)) {
				var shit:ModchartText = PlayState.instance.modchartTexts.get(tag);
				if(!shit.wasAdded) {
					getInstance().add(shit);
					shit.wasAdded = true;
				}
			}
		});

		Lua_helper.set_static_callback("removeLuaText", function(_, tag:String, destroy:Bool = true) {
			if(!PlayState.instance.modchartTexts.exists(tag)) return;
			var pee:ModchartText = PlayState.instance.modchartTexts.get(tag);

			if(destroy)
				pee.kill();

			if(pee.wasAdded) {
				getInstance().remove(pee, true);
				pee.wasAdded = false;
			}

			if(destroy) {
				pee.destroy();
				PlayState.instance.modchartTexts.remove(tag);
			}
		});

		Lua_helper.set_static_callback("setTextString", function(l:FunkinLua, tag:String, text:String) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null) {
				obj.text = text;
				return true;
			}
			l.luaTrace("setTextString: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});

		Lua_helper.set_static_callback("setTextSize", function(l:FunkinLua, tag:String, size:Int) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null) {
				obj.size = size;
				return true;
			}
			l.luaTrace("setTextSize: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});

		Lua_helper.set_static_callback("setTextWidth", function(l:FunkinLua, tag:String, width:Float) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null) {
				obj.fieldWidth = width;
				return true;
			}
			l.luaTrace("setTextWidth: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});

		Lua_helper.set_static_callback("setTextBorder", function(l:FunkinLua, tag:String, size:Int, color:String) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null) {
				var colorNum:Int = Std.parseInt(color);
				if(!color.startsWith('0x')) colorNum = Std.parseInt('0xff' + color);

				obj.borderSize = size;
				obj.borderColor = colorNum;
				return true;
			}
			l.luaTrace("setTextBorder: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});

		Lua_helper.set_static_callback("setTextColor", function(l:FunkinLua, tag:String, color:String) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null) {
				var colorNum:Int = Std.parseInt(color);
				if(!color.startsWith('0x')) colorNum = Std.parseInt('0xff' + color);

				obj.color = colorNum;
				return true;
			}
			l.luaTrace("setTextColor: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});

		Lua_helper.set_static_callback("setTextFont", function(l:FunkinLua, tag:String, newFont:String) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null) {
				obj.font = Paths.font(newFont);
				return true;
			}
			l.luaTrace("setTextFont: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});

		Lua_helper.set_static_callback("setTextItalic", function(l:FunkinLua, tag:String, italic:Bool) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null) {
				obj.italic = italic;
				return true;
			}
			l.luaTrace("setTextItalic: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});

		Lua_helper.set_static_callback("setTextAlignment", function(l:FunkinLua, tag:String, alignment:String = 'left') {
			var obj:FlxText = getTextObject(tag);
			if(obj != null) {
				obj.alignment = LEFT;
				switch(alignment.trim().toLowerCase()) {
					case 'right':
						obj.alignment = RIGHT;
					case 'center':
						obj.alignment = CENTER;
				}
				return true;
			}
			l.luaTrace("setTextAlignment: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});

		Lua_helper.set_static_callback("getTextString", function(l:FunkinLua, tag:String) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null && obj.text != null) return obj.text;
			l.luaTrace("getTextString: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return null;
		});

		Lua_helper.set_static_callback("getTextSize", function(l:FunkinLua, tag:String) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null) return obj.size;
			l.luaTrace("getTextSize: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return -1;
		});

		Lua_helper.set_static_callback("getTextFont", function(l:FunkinLua, tag:String) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null) return obj.font;
			l.luaTrace("getTextFont: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return null;
		});

		Lua_helper.set_static_callback("getTextWidth", function(l:FunkinLua, tag:String) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null) return obj.fieldWidth;
			l.luaTrace("getTextWidth: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return -1;
		});


		// savedatas
		Lua_helper.set_static_callback("initSaveData", function(l:FunkinLua, name:String, ?folder:String = 'psychenginemods') {
			if(PlayState.instance.modchartSaves.exists(name)) {
				l.luaTrace('initSaveData: Save file already initialized: ' + name);
				return;
			}
			var save:FlxSave = new FlxSave();
			save.bind(name, CoolUtil.getSavePath(folder));
			PlayState.instance.modchartSaves.set(name, save);
		});
		Lua_helper.set_static_callback("flushSaveData", function(l:FunkinLua, name:String) {
			if(!PlayState.instance.modchartSaves.exists(name)) {
				l.luaTrace('flushSaveData: Save file not initialized: ' + name, false, false, FlxColor.RED);
				return;
			}
			PlayState.instance.modchartSaves.get(name).flush();
		});

		Lua_helper.set_static_callback("getDataFromSave", function(l:FunkinLua, name:String, field:String, ?defaultValue:Dynamic = null) {
			if(!PlayState.instance.modchartSaves.exists(name)) {
				l.luaTrace('getDataFromSave: Save file not initialized: ' + name, false, false, FlxColor.RED);
				return defaultValue;
			}
			return Reflect.field(PlayState.instance.modchartSaves.get(name).data, field);
		});

		Lua_helper.set_static_callback("setDataFromSave", function(l:FunkinLua, name:String, field:String, value:Dynamic) {
			if(!PlayState.instance.modchartSaves.exists(name)) {
				l.luaTrace('setDataFromSave: Save file not initialized: ' + name, false, false, FlxColor.RED);
				return;
			}
			Reflect.setField(PlayState.instance.modchartSaves.get(name).data, field, value);
		});


		// files
		Lua_helper.set_static_callback("checkFileExists", function(_, filename:String, ?absolute:Bool = false) {
			#if MODS_ALLOWED
			if(absolute)
			{
				return FileSystem.exists(filename);
			}

			var path:String = Paths.modFolders(filename);
			if(FileSystem.exists(path))
			{
				return true;
			}
			return FileSystem.exists(Paths.getPath('assets/$filename', TEXT));
			#else
			if(absolute)
			{
				return Assets.exists(filename);
			}
			return Assets.exists(Paths.getPath('assets/$filename', TEXT));
			#end
		});

		Lua_helper.set_static_callback("saveFile", function(l:FunkinLua, path:String, content:String, ?absolute:Bool = false)
		{
			try {
				if(!absolute)
					File.saveContent(Paths.mods(path), content);
				else
					File.saveContent(path, content);

				return true;
			} catch (e:Dynamic) {
				l.luaTrace("saveFile: Error trying to save " + path + ": " + e, false, false, FlxColor.RED);
			}
			return false;
		});

		Lua_helper.set_static_callback("deleteFile", function(l:FunkinLua, path:String, ?ignoreModFolders:Bool = false)
		{
			try {
				#if MODS_ALLOWED
				if(!ignoreModFolders)
				{
					var lePath:String = Paths.modFolders(path);
					if(FileSystem.exists(lePath))
					{
						FileSystem.deleteFile(lePath);
						return true;
					}
				}
				#end

				var lePath:String = Paths.getPath(path, TEXT);
				if(Assets.exists(lePath))
				{
					FileSystem.deleteFile(lePath);
					return true;
				}
			} catch (e:Dynamic) {
				l.luaTrace("deleteFile: Error trying to delete " + path + ": " + e, false, false, FlxColor.RED);
			}
			return false;
		});

		Lua_helper.set_static_callback("getTextFromFile", function(_, path:String, ?ignoreModFolders:Bool = false) {
			return Paths.getTextFromFile(path, ignoreModFolders);
		});

		Lua_helper.set_static_callback("directoryFileList", function(l:FunkinLua, folder:String) {
			var list:Array<String> = [];
			#if sys
			if(FileSystem.exists(folder)) {
				for (folder in FileSystem.readDirectory(folder)) {
					if (!list.contains(folder)) {
						list.push(folder);
					}
				}
			}
			#end
			return list;
		});


		// randomer
		Lua_helper.set_static_callback("getRandomInt", function(_, min:Int, max:Int = FlxMath.MAX_VALUE_INT, exclude:String = '') {
			var excludeArray:Array<String> = exclude.split(',');
			var toExclude:Array<Int> = [];
			for (i in 0...excludeArray.length)
				toExclude.push(Std.parseInt(excludeArray[i].trim()));

			return FlxG.random.int(min, max, toExclude);
		});

		Lua_helper.set_static_callback("getRandomFloat", function(_, min:Float, max:Float = 1, exclude:String = '') {
			var excludeArray:Array<String> = exclude.split(',');
			var toExclude:Array<Float> = [];
			for (i in 0...excludeArray.length)
				toExclude.push(Std.parseFloat(excludeArray[i].trim()));

			return FlxG.random.float(min, max, toExclude);
		});

		Lua_helper.set_static_callback("getRandomBool", function(_, chance:Float = 50) {
			return FlxG.random.bool(chance);
		});


		// tools
		Lua_helper.set_static_callback("getColorFromHex", function(_, color:String) {
			if(!color.startsWith('0x')) color = '0xff' + color;
			return Std.parseInt(color);
		});

		Lua_helper.set_static_callback("stringStartsWith", function(l:FunkinLua, str:String, start:String) {
			return str.startsWith(start);
		});
		Lua_helper.set_static_callback("stringEndsWith", function(l:FunkinLua, str:String, end:String) {
			return str.endsWith(end);
		});
		Lua_helper.set_static_callback("stringSplit", function(l:FunkinLua, str:String, split:String) {
			return str.split(split);
		});
		Lua_helper.set_static_callback("stringTrim", function(l:FunkinLua, str:String) {
			return str.trim();
		});

		// DEPRECATED, DONT MESS WITH THESE SHITS, ITS JUST THERE FOR BACKWARD COMPATIBILITY
		Lua_helper.set_static_callback("objectPlayAnimation", function(l:FunkinLua, obj:String, name:String, forced:Bool = false, ?startFrame:Int = 0) {
			l.luaTrace('objectPlayAnimation is deprecated! Use playAnim instead', false, true);
			if(PlayState.instance.getLuaObject(obj,false) != null) {
				PlayState.instance.getLuaObject(obj,false).animation.play(name, forced, false, startFrame);
				return true;
			}

			var spr:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if(spr != null) {
				spr.animation.play(name, forced, false, startFrame);
				return true;
			}
			return false;
		});
		Lua_helper.set_static_callback("characterPlayAnim", function(l:FunkinLua, character:String, anim:String, ?forced:Bool = false) {
			l.luaTrace("characterPlayAnim is deprecated! Use playAnim instead", false, true);
			switch(character.toLowerCase()) {
				case 'dad':
					if(PlayState.instance.dad.animOffsets.exists(anim))
						PlayState.instance.dad.playAnim(anim, forced);
				case 'gf' | 'girlfriend':
					if(PlayState.instance.gf != null && PlayState.instance.gf.animOffsets.exists(anim))
						PlayState.instance.gf.playAnim(anim, forced);
				default:
					if(PlayState.instance.boyfriend.animOffsets.exists(anim))
						PlayState.instance.boyfriend.playAnim(anim, forced);
			}
		});

		Lua_helper.set_static_callback("luaSpriteMakeGraphic", function(l:FunkinLua, tag:String, width:Int, height:Int, color:String) {
			l.luaTrace("luaSpriteMakeGraphic is deprecated! Use makeGraphic instead", false, true);
			if(PlayState.instance.modchartSprites.exists(tag)) {
				var colorNum:Int = Std.parseInt(color);
				if(!color.startsWith('0x')) colorNum = Std.parseInt('0xff' + color);

				PlayState.instance.modchartSprites.get(tag).makeGraphic(width, height, colorNum);
			}
		});
		Lua_helper.set_static_callback("luaSpriteAddAnimationByPrefix", function(l:FunkinLua, tag:String, name:String, prefix:String, framerate:Int = 24, loop:Bool = true) {
			l.luaTrace("luaSpriteAddAnimationByPrefix is deprecated! Use addAnimationByPrefix instead", false, true);
			if(PlayState.instance.modchartSprites.exists(tag)) {
				var cock:ModchartSprite = PlayState.instance.modchartSprites.get(tag);
				cock.animation.addByPrefix(name, prefix, framerate, loop);
				if(cock.animation.curAnim == null) {
					cock.animation.play(name, true);
				}
			}
		});
		Lua_helper.set_static_callback("luaSpriteAddAnimationByIndices", function(l:FunkinLua, tag:String, name:String, prefix:String, indices:String, framerate:Int = 24) {
			l.luaTrace("luaSpriteAddAnimationByIndices is deprecated! Use addAnimationByIndices instead", false, true);
			if(PlayState.instance.modchartSprites.exists(tag)) {
				var strIndices:Array<String> = indices.trim().split(',');
				var die:Array<Int> = [];
				for (i in 0...strIndices.length) {
					die.push(Std.parseInt(strIndices[i]));
				}
				var pussy:ModchartSprite = PlayState.instance.modchartSprites.get(tag);
				pussy.animation.addByIndices(name, prefix, die, '', framerate, false);
				if(pussy.animation.curAnim == null) {
					pussy.animation.play(name, true);
				}
			}
		});
		Lua_helper.set_static_callback("luaSpritePlayAnimation", function(l:FunkinLua, tag:String, name:String, forced:Bool = false) {
			l.luaTrace("luaSpritePlayAnimation is deprecated! Use playAnim instead", false, true);
			if(PlayState.instance.modchartSprites.exists(tag)) {
				PlayState.instance.modchartSprites.get(tag).animation.play(name, forced);
			}
		});
		Lua_helper.set_static_callback("setLuaSpriteCamera", function(l:FunkinLua, tag:String, camera:String = '') {
			l.luaTrace("setLuaSpriteCamera is deprecated! Use setObjectCamera instead", false, true);
			if(PlayState.instance.modchartSprites.exists(tag)) {
				PlayState.instance.modchartSprites.get(tag).cameras = [cameraFromString(camera)];
				return true;
			}
			l.luaTrace("Lua sprite with tag: " + tag + " doesn't exist!");
			return false;
		});
		Lua_helper.set_static_callback("setLuaSpriteScrollFactor", function(l:FunkinLua, tag:String, scrollX:Float, scrollY:Float) {
			l.luaTrace("setLuaSpriteScrollFactor is deprecated! Use setScrollFactor instead", false, true);
			if(PlayState.instance.modchartSprites.exists(tag)) {
				PlayState.instance.modchartSprites.get(tag).scrollFactor.set(scrollX, scrollY);
				return true;
			}
			return false;
		});
		Lua_helper.set_static_callback("scaleLuaSprite", function(l:FunkinLua, tag:String, x:Float, y:Float) {
			l.luaTrace("scaleLuaSprite is deprecated! Use scaleObject instead", false, true);
			if(PlayState.instance.modchartSprites.exists(tag)) {
				var shit:ModchartSprite = PlayState.instance.modchartSprites.get(tag);
				shit.scale.set(x, y);
				shit.updateHitbox();
				return true;
			}
			return false;
		});
		Lua_helper.set_static_callback("getPropertyLuaSprite", function(l:FunkinLua, tag:String, variable:String) {
			l.luaTrace("getPropertyLuaSprite is deprecated! Use getProperty instead", false, true);
			if(PlayState.instance.modchartSprites.exists(tag)) {
				var killMe:Array<String> = variable.split('.');
				if(killMe.length > 1) {
					var coverMeInPiss:Dynamic = Reflect.getProperty(PlayState.instance.modchartSprites.get(tag), killMe[0]);
					for (i in 1...killMe.length-1) {
						coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
					}
					return Reflect.getProperty(coverMeInPiss, killMe[killMe.length-1]);
				}
				return Reflect.getProperty(PlayState.instance.modchartSprites.get(tag), variable);
			}
			return null;
		});
		Lua_helper.set_static_callback("setPropertyLuaSprite", function(l:FunkinLua, tag:String, variable:String, value:Dynamic) {
			l.luaTrace("setPropertyLuaSprite is deprecated! Use setProperty instead", false, true);
			if(PlayState.instance.modchartSprites.exists(tag)) {
				var killMe:Array<String> = variable.split('.');
				if(killMe.length > 1) {
					var coverMeInPiss:Dynamic = Reflect.getProperty(PlayState.instance.modchartSprites.get(tag), killMe[0]);
					for (i in 1...killMe.length-1) {
						coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
					}
					Reflect.setProperty(coverMeInPiss, killMe[killMe.length-1], value);
					return true;
				}
				Reflect.setProperty(PlayState.instance.modchartSprites.get(tag), variable, value);
				return true;
			}
			l.luaTrace("setPropertyLuaSprite: Lua sprite with tag: " + tag + " doesn't exist!");
			return false;
		});

		Lua_helper.set_static_callback("musicFadeIn", function(l:FunkinLua, duration:Float, fromValue:Float = 0, toValue:Float = 1) {
			l.luaTrace("musicFadeIn is deprecated! Use soundFadeIn instead.", false, true);
			FlxG.sound.music.fadeIn(duration, fromValue, toValue);
		});
		Lua_helper.set_static_callback("musicFadeOut", function(l:FunkinLua, duration:Float, toValue:Float = 0) {
			l.luaTrace("musicFadeOut is deprecated! Use soundFadeOut instead.", false, true);
			FlxG.sound.music.fadeOut(duration, toValue);
		});


		// Other stuff
		Lua_helper.set_static_callback("debugPrint", true, function(lua:State, fl:FunkinLua) {
			var texts:Array<Dynamic> = Lua_helper.getarguments(lua);
			if (texts.length <= 0) return 0;
			var text:String = Std.isOfType(texts[0], String) ? texts[0] : '';
			for (i in 1...texts.length) {
				var s:String = texts[i];
				if (Std.isOfType(s, String)) text += ", " + s;
			}
			fl.luaTrace(text, true, false);
			return 0;
		});

		Lua_helper.set_static_callback("changePresence", function(l:FunkinLua, details:String, state:Null<String>, ?smallImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float) {
			#if desktop
			PlayState.instance.presenceChangedByLua = true;
			DiscordClient.changePresence(details, state, smallImageKey, hasStartTimestamp, endTimestamp);
			#end
		});
	}
	#end

	public static function isOfTypes(value:Any, types:Array<Dynamic>):Bool {
		for (type in types) if(Std.isOfType(value, type)) return true;
		return false;
	}

	public static function setVarInArray(instance:Dynamic, variable:String, value:Dynamic):Bool {
		var ind = variable.indexOf('[');
		if (ind == -1) {
			//if (PlayState.instance.variables.exists(variable)) PlayState.instance.variables.set(variable, value);
			Reflect.setProperty(instance, variable, value);
			return true;
		}

		var obj:Dynamic = Reflect.getProperty(instance, variable.substr(0, ind)), key:Dynamic, pind;
		while((pind = ind) != -1) {
			//if (obj == null) return false;
			if ((ind = variable.indexOf('[', ind + 1)) == -1) {
				key = variable.substr(pind + 1);
				obj[key] = value;
				break;
			}

			key = variable.substring(pind + 1, ind - 2);
			obj = obj[key];
		}

		return true;
	}

	public static function getVarInArray(instance:Dynamic, variable:String):Dynamic {
		var ind = variable.indexOf('[');
		if (ind == -1) return Reflect.getProperty(instance, variable);

		var obj:Dynamic = Reflect.getProperty(instance, variable.substr(0, ind)), key:Dynamic;
		while(ind != -1) {
			//if (obj == null) break;
			key = variable.substring(ind + 1, (ind = variable.indexOf('[', ind + 1)) == -1 ? variable.length - 1 : ind - 2);
			obj = obj[key];
		}

		return obj;
	}

	static function setGroupStuff(leArray:Dynamic, variable:String, value:Dynamic) {
		var killMe:Array<String> = variable.split('.');
		if (killMe.length > 1) {
			var coverMeInPiss:Dynamic = Reflect.getProperty(leArray, killMe[0]);
			for (i in 1...killMe.length-1)
				coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);

			return Reflect.setProperty(coverMeInPiss, killMe[killMe.length-1], value);
		}

		Reflect.setProperty(leArray, variable, value);
	}

	static function getGroupStuff(leArray:Dynamic, variable:String) {
		var killMe:Array<String> = variable.split('.');
		if (killMe.length > 1) {
			var coverMeInPiss:Dynamic = Reflect.getProperty(leArray, killMe[0]);
			for (i in 1...killMe.length-1)
				coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);

			return switch(Type.typeof(coverMeInPiss)) {
				case ValueType.TClass(haxe.ds.StringMap) | ValueType.TClass(haxe.ds.ObjectMap) | ValueType.TClass(haxe.ds.IntMap) | ValueType.TClass(haxe.ds.EnumValueMap):
					coverMeInPiss.get(killMe[killMe.length-1]);
				default:
					Reflect.getProperty(coverMeInPiss, killMe[killMe.length-1]);
			}
		}

		return switch(Type.typeof(leArray)) {
			case ValueType.TClass(haxe.ds.StringMap) | ValueType.TClass(haxe.ds.ObjectMap) | ValueType.TClass(haxe.ds.IntMap) | ValueType.TClass(haxe.ds.EnumValueMap):
				leArray.get(variable);
			default:
				Reflect.getProperty(leArray, variable);
		}
	}

	// deprecated lmfao
	public static function getPropertyLoopThingWhatever(killMe:Array<String>, ?checkForTextsToo:Bool = true, ?getProperty:Bool = true):Dynamic {
		var coverMeInPiss:Dynamic = getObjectDirectly(killMe[0], checkForTextsToo);
		var end:Int = killMe.length - (getProperty ? 1 : 0);
		for (i in 1...end)
			coverMeInPiss = getVarInArray(coverMeInPiss, killMe[i]);

		return coverMeInPiss;
	}

	public static function getObjectDirectly(objectName:String, checkForTextsToo:Bool = true):Dynamic {
		var obj = PlayState.instance.getLuaObject(objectName, checkForTextsToo);
		if (obj == null) return getVarInArray(getInstance(), objectName);
		return obj;
	}

	public static function setVarInObject(obj:Dynamic, variable:String, value:Dynamic):Bool {
		var ind = variable.indexOf('.');
		if (ind == -1) return setVarInArray(obj, variable, value);

		var obj:Dynamic = getVarInArray(obj, variable.substr(0, ind)), pind;
		while((pind = ind) != -1) {
			//if (obj == null) return false;
			if ((ind = variable.indexOf('.', ind + 1)) == -1)
				return setVarInArray(obj, variable.substr(pind + 1), value);

			obj = getVarInArray(obj, variable.substring(pind + 1, ind));
		}

		return true;
	}

	public static function getVarInObject(obj:Dynamic, variable:String):Dynamic {
		var ind = variable.indexOf('.');
		if (ind == -1) return getVarInArray(obj, variable);

		var obj:Dynamic = getVarInArray(obj, variable.substr(0, ind));
		while(ind != -1) {
			//if (obj == null) break;
			obj = getVarInArray(obj, variable.substring(ind + 1, (ind = variable.indexOf('.', ind + 1)) == -1 ? variable.length : ind));
		}

		return obj;
	}

	public static function setVarInstance(variable:String, value:Dynamic, checkForTextsToo:Bool = true):Bool {
		var ind = variable.indexOf('.');
		if (ind == -1) {
			if (PlayState.instance.variables.exists(variable)) {
				if (value == null) PlayState.instance.variables.remove(variable);
				else PlayState.instance.variables.set(variable, value);
				return true;
			}
			return setVarInArray(getInstance(), variable, value);
		}

		var obj:Dynamic = getObjectDirectly(variable.substr(0, ind), checkForTextsToo), pind;
		while((pind = ind) != -1) {
			//if (obj == null) return false;
			if ((ind = variable.indexOf('.', ind + 1)) == -1)
				return setVarInArray(obj, variable.substr(pind + 1), value);

			obj = getVarInArray(obj, variable.substring(pind + 1, ind));
		}

		return true;
	}

	public static function getVarInstance(variable:String, checkLuaFirst:Bool = true, checkForTextsToo:Bool = true):Dynamic {
		var ind = variable.indexOf('.');
		if (ind == -1) {
			if (PlayState.instance.variables.exists(variable)) return PlayState.instance.variables.get(variable);
			return checkLuaFirst ? getObjectDirectly(variable, checkForTextsToo) : getVarInArray(getInstance(), variable);
		}

		var obj:Dynamic = getObjectDirectly(variable.substr(0, ind), checkForTextsToo);
		while(ind != -1) {
			//if (obj == null) break;
			obj = getVarInArray(obj, variable.substring(ind + 1, (ind = variable.indexOf('.', ind + 1)) == -1 ? variable.length : ind));
		}

		return obj;
	}

	inline static function getTextObject(name:String):FlxText
		return PlayState.instance.modchartTexts.exists(name) ? PlayState.instance.modchartTexts.get(name) : Reflect.getProperty(PlayState.instance, name);

	static function resetTextTag(tag:String) {
		if (!PlayState.instance.modchartTexts.exists(tag)) return;
		var pee:ModchartText = PlayState.instance.modchartTexts.get(tag);
		pee.kill();

		if(pee.wasAdded)
			PlayState.instance.remove(pee, true);

		pee.destroy();
		PlayState.instance.modchartTexts.remove(tag);
	}

	static function resetSpriteTag(tag:String) {
		if (!PlayState.instance.modchartSprites.exists(tag)) return;
		var pee:ModchartSprite = PlayState.instance.modchartSprites.get(tag);
		pee.kill();
		if(pee.wasAdded)
			PlayState.instance.remove(pee, true);

		pee.destroy();
		PlayState.instance.modchartSprites.remove(tag);
	}

	static function tweenShit(tag:String, vars:String) {
		cancelTween(tag);
		return getVarInstance(vars);
	}

	static function cancelTween(tag:String) {
		if(PlayState.instance.modchartTweens.exists(tag)) {
			PlayState.instance.modchartTweens.get(tag).cancel();
			PlayState.instance.modchartTweens.get(tag).destroy();
			PlayState.instance.modchartTweens.remove(tag);
		}
	}

	static function cancelTimer(tag:String) {
		if (PlayState.instance.modchartTimers.exists(tag)) {
			var theTimer:FlxTimer = PlayState.instance.modchartTimers.get(tag);
			theTimer.cancel();
			theTimer.destroy();
			PlayState.instance.modchartTimers.remove(tag);
		}
	}

	static function addAnimByIndices(obj:String, name:String, prefix:String, indices:String, framerate:Int = 24, loop:Bool = false) {
		var strIndices:Array<String> = indices.trim().split(',');
		var die:Array<Int> = [];
		for (i in 0...strIndices.length)
			die.push(Std.parseInt(strIndices[i]));

		if (PlayState.instance.getLuaObject(obj, false) != null) {
			var pussy:FlxSprite = PlayState.instance.getLuaObject(obj, false);
			pussy.animation.addByIndices(name, prefix, die, '', framerate, loop);
			if(pussy.animation.curAnim == null) pussy.animation.play(name, true);

			return true;
		}

		var pussy:FlxSprite = Reflect.getProperty(getInstance(), obj);
		if (pussy != null) {
			pussy.animation.addByIndices(name, prefix, die, '', framerate, loop);
			if(pussy.animation.curAnim == null) pussy.animation.play(name, true);

			return true;
		}
		return false;
	}

	static function loadFrames(spr:FlxSprite, image:String, spriteType:String) {
		switch(spriteType.toLowerCase().trim()) {
			case "texture" | "textureatlas" | "tex":
				spr.frames = AtlasFrameMaker.construct(image);
			case "texture_noaa" | "textureatlas_noaa" | "tex_noaa":
				spr.frames = AtlasFrameMaker.construct(image, null, true);
			case "packer" | "packeratlas" | "pac":
				spr.frames = Paths.getPackerAtlas(image);
			default:
				spr.frames = Paths.getSparrowAtlas(image);
		}
	}

	static function getFlxEaseByString(ease:String) {
		switch(ease.toLowerCase().trim()) {
			case 'backin': return FlxEase.backIn;
			case 'backinout': return FlxEase.backInOut;
			case 'backout': return FlxEase.backOut;
			case 'bouncein': return FlxEase.bounceIn;
			case 'bounceinout': return FlxEase.bounceInOut;
			case 'bounceout': return FlxEase.bounceOut;
			case 'circin': return FlxEase.circIn;
			case 'circinout': return FlxEase.circInOut;
			case 'circout': return FlxEase.circOut;
			case 'cubein': return FlxEase.cubeIn;
			case 'cubeinout': return FlxEase.cubeInOut;
			case 'cubeout': return FlxEase.cubeOut;
			case 'elasticin': return FlxEase.elasticIn;
			case 'elasticinout': return FlxEase.elasticInOut;
			case 'elasticout': return FlxEase.elasticOut;
			case 'expoin': return FlxEase.expoIn;
			case 'expoinout': return FlxEase.expoInOut;
			case 'expoout': return FlxEase.expoOut;
			case 'quadin': return FlxEase.quadIn;
			case 'quadinout': return FlxEase.quadInOut;
			case 'quadout': return FlxEase.quadOut;
			case 'quartin': return FlxEase.quartIn;
			case 'quartinout': return FlxEase.quartInOut;
			case 'quartout': return FlxEase.quartOut;
			case 'quintin': return FlxEase.quintIn;
			case 'quintinout': return FlxEase.quintInOut;
			case 'quintout': return FlxEase.quintOut;
			case 'sinein': return FlxEase.sineIn;
			case 'sineinout': return FlxEase.sineInOut;
			case 'sineout': return FlxEase.sineOut;
			case 'smoothstepin': return FlxEase.smoothStepIn;
			case 'smoothstepinout': return FlxEase.smoothStepInOut;
			case 'smoothstepout': return FlxEase.smoothStepInOut;
			case 'smootherstepin': return FlxEase.smootherStepIn;
			case 'smootherstepinout': return FlxEase.smootherStepInOut;
			case 'smootherstepout': return FlxEase.smootherStepOut;
		}
		return FlxEase.linear;
	}

	static function blendModeFromString(blend:String):BlendMode {
		switch(blend.toLowerCase().trim()) {
			case 'add': return ADD;
			case 'alpha': return ALPHA;
			case 'darken': return DARKEN;
			case 'difference': return DIFFERENCE;
			case 'erase': return ERASE;
			case 'hardlight': return HARDLIGHT;
			case 'invert': return INVERT;
			case 'layer': return LAYER;
			case 'lighten': return LIGHTEN;
			case 'multiply': return MULTIPLY;
			case 'overlay': return OVERLAY;
			case 'screen': return SCREEN;
			case 'shader': return SHADER;
			case 'subtract': return SUBTRACT;
		}
		return NORMAL;
	}

	static function cameraFromString(cam:String):FlxCamera {
		switch(cam.toLowerCase().trim()) {
			case 'camhud' | 'hud': return PlayState.instance.camHUD;
			case 'camother' | 'other': return PlayState.instance.camOther;
		}
		return PlayState.instance.camGame;
	}

	#if (!flash && sys)
	static public function getShader(obj:String):FlxRuntimeShader {
		var leObj:FlxSprite = getVarInstance(obj, true, false);
		if (leObj != null) return cast leObj.shader;
		return null;
	}
	#end

	public function luaTrace(text:String, ignoreCheck:Bool = false, deprecated:Bool = false, color:FlxColor = FlxColor.WHITE) {
		#if LUA_ALLOWED
		if(ignoreCheck || getBool('luaDebugMode')) {
			if(deprecated && !getBool('luaDeprecatedWarnings')) return;
			PlayState.instance.addTextToDebug(text, color);

			haxe.Log.trace(text, cast {fileName: scriptName, lineNumber: 0});
		}
		#end
	}

	var lastCalledFunction:String = '';
	public function call(func:String, ?args:Array<Any>):Dynamic {
		#if LUA_ALLOWED
		if (closed) return Function_Continue;
		lastCalledFunction = func;

		Lua.getglobal(lua, func);
		var type:Int = Lua.type(lua, -1);

		if (type != Lua.LUA_TFUNCTION) {
			if (type > Lua.LUA_TNIL)
				luaTrace('ERROR ($func)): attempt to call a ${Lua.typename(lua, type)} value as a callback', false, false, FlxColor.RED);

			Lua.pop(lua, 1);
			return Function_Continue;
		}

		var nargs:Int = 0;
		if (args != null) for (arg in args) {
			if (Convert.toLua(lua, arg)) nargs++;
			else luaTrace('WARNING ($func)): attempt to insert ${Type.typeof(arg)} (unsupported value type) as a argument', false, false, FlxColor.ORANGE);
		}
		var status:Int = Lua.pcall(lua, nargs, 1, 0);

		if (status != Lua.LUA_OK) {
			luaTrace('ERROR ($func)): ${getErrorMessage(status)}', false, false, FlxColor.RED);
			return Function_Continue;
		}

		var resultType:Int = Lua.type(lua, -1);
		if (!resultIsAllowed(resultType)) {
			luaTrace('WARNING ($func): unsupported returned value type ("${Lua.typename(lua, resultType)}")', false, false, FlxColor.ORANGE);
			Lua.pop(lua, 1);
			return Function_Continue;
		}

		var result:Dynamic = cast Convert.fromLua(lua, -1);
		if (result == null) result = Function_Continue;

		Lua.pop(lua, 1);
		return result;
		#else
		return Function_Continue;
		#end
	}

	function getErrorMessage(status:Int = 0):String {
		#if LUA_ALLOWED
		if (lua == null) return null;
		var v:String = Lua.tostring(lua, -1);
		Lua.pop(lua, 1);

		if (v != null) v = v.trim();
		if (v == null || v == "") {
			return switch(status) {
				case Lua.LUA_ERRSYNTAX: "Syntax Error";
				case Lua.LUA_ERRRUN: "Runtime Error";
				case Lua.LUA_ERRMEM: "Memory Allocation Error";
				case Lua.LUA_ERRERR: "Critical Error";
				default: "Unknown Error";
			}
		}
		return v;
		#else
		return null;
		#end
	}

	#if LUA_ALLOWED
	inline public function error(fmt:String) {
		#if (linc_luajit >= "0.0.6")
		if (lua != null) LuaL.error(lua, fmt);
		#end
	}

	inline static function resultIsAllowed(type:Int):Bool {
		return type >= Lua.LUA_TNIL && type <= Lua.LUA_TTABLE && type != Lua.LUA_TLIGHTUSERDATA;
	}

	static function hasValidArgs(state:State, neededArgs:Int):Bool {
		var uwu:Bool = Lua.gettop(state) >= neededArgs;
		if (!uwu) Lua.pushnil(state);
		return uwu;
	}
	#end

	public function set(variable:String, data:Any) {
		#if LUA_ALLOWED
		if (lua == null) return;
		Convert.toLua(lua, data);
		Lua.setglobal(lua, variable);
		#end
	}

	public function getBool(variable:String):Bool {
		#if LUA_ALLOWED
		if (lua == null) return false;
		Lua.getglobal(lua, variable);

		var result:Bool = Lua.toboolean(lua, -1);
		Lua.pop(lua, 1);

		return result;
		#end
		return false;
	}

	public function stop() {
		trace('closing lua script $scriptName');
		PlayState.instance.luaArray.remove(this);
		closed = true;

		#if LUA_ALLOWED
		if (lua == null) return;
		Lua_helper.terminate_callbacks(lua);
		Lua.close(lua);
		lua = null;
		#end
	}

	public static inline function getInstance()
		return PlayState.instance.isDead ? GameOverSubstate.instance : PlayState.instance;
}

class ModchartSprite extends FlxSprite
{
	public var wasAdded:Bool = false;
	public var animOffsets:Map<String, Array<Float>> = new Map<String, Array<Float>>();
	//public var isInFront:Bool = false;

	public function new(?x:Float = 0, ?y:Float = 0)
	{
		super(x, y);
		antialiasing = ClientPrefs.globalAntialiasing;
	}
}

class ModchartText extends FlxText
{
	public var wasAdded:Bool = false;
	public function new(x:Float, y:Float, text:String, width:Float)
	{
		super(x, y, width, text, 16);
		setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		cameras = [PlayState.instance.camHUD];
		scrollFactor.set();
		borderSize = 2;
		antialiasing = ClientPrefs.globalAntialiasing;
	}
}

class DebugLuaText extends FlxText
{
	private var disableTime:Float = 6;
	public var parentGroup:FlxTypedGroup<DebugLuaText>;
	public function new(text:String, parentGroup:FlxTypedGroup<DebugLuaText>, color:FlxColor) {
		this.parentGroup = parentGroup;
		super(10, 10, 0, text, 16);
		setFormat(Paths.font("vcr.ttf"), 16, color, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scrollFactor.set();
		borderSize = 1;
	}

	override function update(elapsed:Float) {
		super.update(elapsed);
		disableTime -= elapsed;
		if(disableTime < 0) disableTime = 0;
		if(disableTime < 1) alpha = disableTime;
	}
}

class CustomSubstate extends MusicBeatSubstate
{
	public static var name:String = 'unnamed';
	public static var instance:CustomSubstate;

	override function create()
	{
		instance = this;

		PlayState.instance.callOnLuas('onCustomSubstateCreate', [name]);
		super.create();
		PlayState.instance.callOnLuas('onCustomSubstateCreatePost', [name]);
	}
	
	public function new(name:String)
	{
		CustomSubstate.name = name;
		super();
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
	}
	
	override function update(elapsed:Float)
	{
		PlayState.instance.callOnLuas('onCustomSubstateUpdate', [name, elapsed]);
		super.update(elapsed);
		PlayState.instance.callOnLuas('onCustomSubstateUpdatePost', [name, elapsed]);
	}

	override function destroy()
	{
		PlayState.instance.callOnLuas('onCustomSubstateDestroy', [name]);
		super.destroy();
	}
}

#if hscript
class HScript
{
	private static var MAX_POOL(default, null):Int = 255;

	public static var parser:Parser = new Parser();
	public var idEnumerator:Int = 0;

	public var exprs:Map<Int, Expr> = new Map(); // safe cache
	private var pool:Map<Int, Expr> = new Map(); // unsafe immediate cache
	private var keys:Map<String, Int> = new Map(); // indices
	private var syek:Map<Int, String> = new Map(); // secidni (for pool)
	private var poolarr:Array<Int> = [];

	public var interp:Interp;

	public var variables(get, never):Map<String, Dynamic>;
	inline public function get_variables()
		return interp.variables;

	public function new() {
		interp = new Interp();

		variables.set('FlxG', FlxG);
		variables.set('FlxSprite', FlxSprite);
		variables.set('FlxCamera', FlxCamera);
		variables.set('FlxTimer', FlxTimer);
		variables.set('FlxTween', FlxTween);
		//@:noCompletion variables.set('FlxPoint', FlxPoint);
		variables.set('FlxEase', FlxEase);
		variables.set('PlayState', PlayState);
		variables.set('game', PlayState.instance);
		variables.set('Paths', Paths);
		variables.set('Conductor', Conductor);
		variables.set('ClientPrefs', ClientPrefs);
		variables.set('Character', Character);
		variables.set('Alphabet', Alphabet);
		variables.set('CustomSubstate', CustomSubstate);
		#if (!flash && sys)
		variables.set('FlxRuntimeShader', FlxRuntimeShader);
		#end
		variables.set('ShaderFilter', openfl.filters.ShaderFilter);
		variables.set('StringTools', StringTools);
		#if VIDEOS_ALLOWED
		variables.set('VideoHandler', VideoHandler);
		variables.set('VideoSprite', VideoSprite);
		#end

		variables.set('setVar', function(name:String, value:Dynamic) {
			PlayState.instance.variables.set(name, value);
		});

		variables.set('getVar', function(name:String) {
			if(PlayState.instance.variables.exists(name)) return PlayState.instance.variables.get(name);
			return null;
		});

		variables.set('removeVar', function(name:String) {
			if(PlayState.instance.variables.exists(name)) {
				PlayState.instance.variables.remove(name);
				return true;
			}
			return false;
		});
	}

	public function parse(code:String):Int {
		if (keys.exists(code)) return keys.get(code);
		var expr:Expr = parser.parseString(code);
		exprs.set(idEnumerator, expr);
		keys.set(code, idEnumerator);
		return idEnumerator++;
	}

	inline public function getExpr(id:Int):Expr
		return exprs.get(id);

	public function execute(expr:Expr):Dynamic {
		@:privateAccess
		parser.line = 1;
		parser.allowTypes = true;
		return interp.execute(expr);
	}

	public function immediateExecute(code:String):Dynamic {
		var expr:Expr;
		if (keys.exists(code)) expr = pool.get(keys.get(code));
		else {
			expr = parser.parseString(code);
			pool.set(idEnumerator, expr);
			keys.set(code, idEnumerator);
			syek.set(idEnumerator, code);
			poolarr.push(idEnumerator);
			idEnumerator++;
			while (poolarr.length > MAX_POOL) {
				var id:Int = poolarr.shift();
				var code:String = syek.get(id);
				syek.remove(id);
				keys.remove(code);
				pool.remove(id);
			}
		}
		return inline execute(expr);
	}

	public function destroy() {
		//idEnumerator = 0;
		//variables.clear();
		exprs.clear();
		pool.clear();
		keys.clear();
		syek.clear();
		poolarr.resize(0);
	}
}
#end
