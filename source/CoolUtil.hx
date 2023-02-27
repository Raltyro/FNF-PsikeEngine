package;

import flixel.input.keyboard.FlxKey;
import flixel.util.FlxSave;
import flixel.FlxG;
import openfl.utils.Assets;
import lime.utils.Assets as LimeAssets;
import lime.utils.AssetLibrary;
import lime.utils.AssetManifest;
#if sys
import sys.io.File;
import sys.io.Process;
import sys.FileSystem;
#else
import openfl.utils.Assets;
#end

import psike.PsikeHash;

using StringTools;

class CoolUtil {
	public static var defaultDifficulties:Array<String> = [
		'Easy',
		'Normal',
		'Hard'
	];
	public static var defaultDifficulty:String = 'Normal'; //The chart that has no suffix and starting difficulty on Freeplay/Story Mode

	public static var difficulties:Array<String> = [];
	public static var lowerDifficulties(get, null):Array<String>;
	inline static function get_lowerDifficulties():Array<String> return [for (v in difficulties) v.toLowerCase()];

	inline public static function quantize(f:Float, snap:Float) { // changed so this actually works lol
		var m:Float = Math.fround(f * snap);
		return (m / snap);
	}
	
	public static function getDifficultyFilePath(num:Null<Int> = null) {
		if(num == null) num = PlayState.storyDifficulty;

		var fileSuffix:String = difficulties[num];
		if (fileSuffix != defaultDifficulty) fileSuffix = '-' + fileSuffix;
		else fileSuffix = '';

		return Paths.formatToSongPath(fileSuffix);
	}

	public static function difficultyString():String
		return difficulties[PlayState.storyDifficulty].toUpperCase();

	inline public static function boundTo(value:Float, min:Float, max:Float):Float
		return Math.max(min, Math.min(max, value));

	public static function truncateFloat(x:Float, precision:Int = 2, round:Bool = false):Float {
		var p = Math.pow(10, precision);
		return (round ? Math.round : Math.floor)(precision > 0 ? p * x : x) / (precision > 0 ? p : 1);
	}

	public static function coolTextFile(path:String):Array<String> {
		#if sys
		if (FileSystem.exists(path)) return listFromString(File.getContent(path));
		#else
		if (Assets.exists(path)) return listFromString(Assets.getText(path));
		#end
		return [];
	}

	public static function listFromString(string:String):Array<String> {
		var daList:Array<String> = [];
		daList = string.trim().split('\n');

		for (i in 0...daList.length) {
			daList[i] = daList[i].trim();
		}

		return daList;
	}

	public static function dominantColor(sprite:flixel.FlxSprite):Int{
		var countByColor:Map<Int, Int> = [];
		for (col in 0...sprite.frameWidth){
			for(row in 0...sprite.frameHeight){
			  var colorOfThisPixel:Int = sprite.pixels.getPixel32(col, row);
			  if(colorOfThisPixel != 0){
				  if(countByColor.exists(colorOfThisPixel)){
				    countByColor[colorOfThisPixel] =  countByColor[colorOfThisPixel] + 1;
				  }else if(countByColor[colorOfThisPixel] != 13520687 - (2*13520687)){
					 countByColor[colorOfThisPixel] = 1;
				  }
			  }
			}
		 }
		var maxCount = 0;
		var maxKey:Int = 0;//after the loop this will store the max color
		countByColor[flixel.util.FlxColor.BLACK] = 0;
			for(key in countByColor.keys()){
			if(countByColor[key] >= maxCount){
				maxCount = countByColor[key];
				maxKey = key;
			}
		}
		return maxKey;
	}

	public static function numberArray(max:Int, ?min = 0):Array<Int> {
		var dumbArray:Array<Int> = [];
		for (i in min...max)
		{
			dumbArray.push(i);
		}
		return dumbArray;
	}

	@:deprecated("`CoolUtil.precacheSound` is deprecated, use `Paths.sound` instead")
	public static function precacheSound(sound:String, ?library:String = null):Void
		Paths.sound(sound, library);

	@:deprecated("`CoolUtil.precacheMusic` is deprecated, use `Paths.music` instead")
	public static function precacheMusic(sound:String, ?library:String = null):Void
		Paths.music(sound, library);
	
	inline public static function flKeyToFlx(keyCode:Int):FlxKey
		@:privateAccess return FlxKey.toStringMap.get(keyCode);

	public static function browserLoad(site:String) {
		#if linux
		Sys.command('/usr/bin/xdg-open', [site]);
		#else
		FlxG.openURL(site);
		#end
	}

	public static var mustUpdate:Bool = false;
	public static var realUpdateVersion:String = null;
	public static var updateVersion(get, null):String;
	static function get_updateVersion():String
		return realUpdateVersion != null ? realUpdateVersion : MainMenuState.psikeEngineVersion.trim();

	public static function getUpdateVersion(?onComplete:String->Void) {
		var http = new haxe.Http("https://raw.githubusercontent.com/Raltyro/FNF-PsikeEngine/main/psikeVersion.txt");

		http.onData = function(data:String) {
			realUpdateVersion = data.split('\n')[0].trim();
			if (onComplete != null) onComplete(realUpdateVersion);
		}

		http.onError = function(error) {
			trace('error: $error');
			if (onComplete != null) onComplete(null);
		}

		http.request();
	}

	public static var realGitCommitHash(get, null):String;
	@:noCompletion inline static function get_realGitCommitHash():String
		return PsikeHash.sha;

	public static var gitCommitHash(get, null):String;
	@:noCompletion inline static function get_gitCommitHash():String
		return realGitCommitHash.substr(0, 7);

	public static function checkForUpdates(?onComplete:Bool->Void):Void {
		if (!mustUpdate && realUpdateVersion != null) mustUpdate = updateVersion != MainMenuState.psikeEngineVersion.trim();
		if (mustUpdate) {
			if (onComplete != null) onComplete(true);
			return;
		}

		getUpdateVersion(function(updateVersion:String) {
			if (updateVersion != null) mustUpdate = updateVersion != MainMenuState.psikeEngineVersion.trim();
			onComplete(mustUpdate);
		});
	}
	
	public static function tryUpdate() {
		CoolUtil.browserLoad("https://github.com/Raltyro/FNF-PsikeEngine");
	}

	inline public static function getSavePath(folder:String = '', prefix:String = 'ShadowMario/PsychEngine'):String
		return prefix + '/' + folder;
}
