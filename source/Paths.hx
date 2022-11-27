package;

import animateatlas.AtlasFrameMaker;
import flixel.math.FlxPoint;
import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import openfl.geom.Rectangle;
import flixel.math.FlxRect;
import haxe.xml.Access;
import openfl.system.System;
import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import lime.utils.Assets;
import flixel.FlxSprite;
#if sys
import sys.io.File;
import sys.FileSystem;
#end
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import haxe.Json;

import flash.media.Sound;

#if cpp
import cpp.vm.Gc;
#elseif hl
import hl.Gc;
#elseif java
import java.vm.Gc;
#elseif neko
import neko.vm.Gc;
#end

using StringTools;

@:access(openfl.display.BitmapData.__texture)
class Paths
{
	inline public static var SOUND_EXT = #if web "mp3" #else "ogg" #end;
	inline public static var VIDEO_EXT = "mp4";

	#if MODS_ALLOWED
	public static var ignoreModFolders:Array<String> = [
		'characters',
		'custom_events',
		'custom_notetypes',
		'data',
		'songs',
		'music',
		'sounds',
		'shaders',
		'videos',
		'images',
		'stages',
		'weeks',
		'fonts',
		'scripts',
		'achievements'
	];
	#end

	public static function excludeAsset(key:String) {
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	public static function assetExcluded(key:String):Bool {
		for (v in dumpExclusions) {
			if (key.endsWith(v)) return true;
		}
		return false;
	}

	public static var dumpExclusions:Array<String> =
	[
		'music/freakyMenu.$SOUND_EXT',
		'music/breakfast.$SOUND_EXT',
		'music/tea-time.$SOUND_EXT',
	];

	private inline static function _compress() {
		#if cpp
		Gc.compact();
		Gc.run(true);
		//Gc.setMinimumWorkingMemory(totalMemory);
		#elseif hl
		Gc.major();
		#elseif (java || neko)
		Gc.run(true);
		#end
	}

	public static function compress(repeat:Int = 1) {
		if (repeat > 1) {
			if (repeat > 32) repeat = 32;
			for (i in 0...repeat) _compress();
		}
		else
			_compress();
	}

	public static function decacheGraphic(key:String) {
		var obj = currentTrackedAssets.get(key);
		@:privateAccess{
			if (obj == null) obj = FlxG.bitmap._cache.get(key);
			if (obj != null) {
				OpenFlAssets.cache.removeBitmapData(key);
				FlxG.bitmap._cache.remove(key);

				if (obj.bitmap != null) {
					obj.bitmap.lock();
					if (obj.bitmap.__texture != null) obj.bitmap.__texture.dispose();
					obj.bitmap.disposeImage();
				}

				obj.destroy();
				currentTrackedAssets.remove(key);
			}
		}
	}

	public static function decacheSound(key:String) {
		var obj = currentTrackedSounds.get(key);
		if (obj == null && OpenFlAssets.cache.hasSound(key)) obj = OpenFlAssets.cache.getSound(key);

		OpenFlAssets.cache.removeSound(key);
		Assets.cache.clear(key);
		currentTrackedSounds.remove(key);

		if (obj != null) {
			@:privateAccess{
				if (obj.__buffer != null) {
					obj.__buffer.dispose();
					obj.__buffer = null;
				}
				obj = null;
			}
		}
	}

	/// haya I love you for the base cache dump I took to the max
	public static function clearUnusedMemory() {
		// clear non local assets in the tracked assets list
		for (key in currentTrackedAssets.keys()) {
			// if it is not currently contained within the used local assets
			if (!localTrackedAssets.contains(key)
				&& !assetExcluded(key)) {
				// get rid of it
				decacheGraphic(key);
			}
		}

		// run the garbage collector for good measure lmfao
		//System.gc();

		compress(3);
	}

	// define the locally tracked assets
	public static var localTrackedAssets:Array<String> = [];
	public static function clearStoredMemory(?cleanUnused:Bool = false) {
		// clear anything not in the tracked assets list
		@:privateAccess
		for (key in FlxG.bitmap._cache.keys())
		{
			if (!currentTrackedAssets.exists(key))
				decacheGraphic(key);
		}

		// clear all sounds that are cached
		for (key in currentTrackedSounds.keys()) {
			if (!localTrackedAssets.contains(key) 
			&& !assetExcluded(key) && key != null)
				decacheSound(key);
		}

		// flags everything to be cleared out next unused memory clear
		localTrackedAssets = [];
		openfl.Assets.cache.clear("songs");
		compress(3);
	}

	static public var currentModDirectory:String = '';
	static public var currentLevel:String;
	static public function setCurrentLevel(name:String)
	{
		currentLevel = name.toLowerCase();
	}

	public static function getPath(file:String, type:AssetType, ?library:Null<String> = null)
	{
		if (library != null)
			return getLibraryPath(file, library);

		if (currentLevel != null)
		{
			var levelPath:String = '';
			if(currentLevel != 'shared') {
				levelPath = getLibraryPathForce(file, currentLevel);
				if (OpenFlAssets.exists(levelPath, type))
					return levelPath;
			}

			levelPath = getLibraryPathForce(file, "shared");
			if (OpenFlAssets.exists(levelPath, type))
				return levelPath;
		}

		return getPreloadPath(file);
	}

	static public function getLibraryPath(file:String, library = "preload")
	{
		return if (library == "preload" || library == "default") getPreloadPath(file); else getLibraryPathForce(file, library);
	}

	inline static function getLibraryPathForce(file:String, library:String)
	{
		var returnPath = '$library:assets/$library/$file';
		return returnPath;
	}

	inline public static function getPreloadPath(file:String = '')
	{
		return 'assets/$file';
	}

	inline static public function file(file:String, type:AssetType = TEXT, ?library:String)
	{
		return getPath(file, type, library);
	}

	inline static public function txt(key:String, ?library:String)
	{
		return getPath('data/$key.txt', TEXT, library);
	}

	inline static public function xml(key:String, ?library:String)
	{
		return getPath('data/$key.xml', TEXT, library);
	}

	inline static public function json(key:String, ?library:String)
	{
		return getPath('data/$key.json', TEXT, library);
	}

	inline static public function shaderFragment(key:String, ?library:String)
	{
		return getPath('shaders/$key.frag', TEXT, library);
	}
	inline static public function shaderVertex(key:String, ?library:String)
	{
		return getPath('shaders/$key.vert', TEXT, library);
	}
	inline static public function lua(key:String, ?library:String)
	{
		return getPath('$key.lua', TEXT, library);
	}

	static public function video(key:String)
	{
		#if MODS_ALLOWED
		var file:String = modsVideo(key);
		if(FileSystem.exists(file)) {
			return file;
		}
		#end
		return 'assets/videos/$key.$VIDEO_EXT';
	}

	static public function sound(key:String, ?library:String):Sound
	{
		var sound:Sound = returnSound('sounds', key, library);
		return sound;
	}

	inline static public function soundRandom(key:String, min:Int, max:Int, ?library:String)
	{
		return sound(key + FlxG.random.int(min, max), library);
	}

	public static var streamMusic:Bool = false;
	static public function music(key:String, ?library:String):Sound
	{
		var file:Sound = returnSound('music', key, library, streamMusic);
		return file;
	}

	static public function voices(song:String):Any
	{
		var songKey:String = '${formatToSongPath(song)}/Voices';
		var voices = returnSound('songs', songKey, streamMusic);
		return voices;
	}

	static public function inst(song:String):Any
	{
		var songKey:String = '${formatToSongPath(song)}/Inst';
		var inst = returnSound('songs', songKey, streamMusic);
		return inst;
	}

	inline static public function image(key:String, ?library:String):FlxGraphic
	{
		// streamlined the assets process more
		var returnAsset:FlxGraphic = returnGraphic(key, library);
		return returnAsset;
	}

	static public function getTextFromFile(key:String, ?ignoreMods:Bool = false):String
	{
		#if sys
		#if MODS_ALLOWED
		if (!ignoreMods && FileSystem.exists(modFolders(key)))
			return File.getContent(modFolders(key));
		#end

		if (FileSystem.exists(getPreloadPath(key)))
			return File.getContent(getPreloadPath(key));

		if (currentLevel != null)
		{
			var levelPath:String = '';
			if(currentLevel != 'shared') {
				levelPath = getLibraryPathForce(key, currentLevel);
				if (FileSystem.exists(levelPath))
					return File.getContent(levelPath);
			}

			levelPath = getLibraryPathForce(key, 'shared');
			if (FileSystem.exists(levelPath))
				return File.getContent(levelPath);
		}
		#end
		return Assets.getText(getPath(key, TEXT));
	}

	inline static public function font(key:String)
	{
		#if MODS_ALLOWED
		var file:String = modsFont(key);
		if(FileSystem.exists(file)) {
			return file;
		}
		#end
		return 'assets/fonts/$key';
	}

	inline static public function fileExists(key:String, type:AssetType, ?ignoreMods:Bool = false, ?library:String):Bool
	{
		#if MODS_ALLOWED
		if(FileSystem.exists(mods(currentModDirectory + '/' + key)) || FileSystem.exists(mods(key)))
			return true;
		#end
		if(OpenFlAssets.exists(getPath(key, type)))
			return true;
		
		return false;
	}

	inline static public function getSparrowAtlas(key:String, ?library:String):FlxAtlasFrames
	{
		#if MODS_ALLOWED
		var imageLoaded:FlxGraphic = returnGraphic(key);
		var xmlExists:Bool = false;
		if(FileSystem.exists(modsXml(key))) {
			xmlExists = true;
		}

		return FlxAtlasFrames.fromSparrow((imageLoaded != null ? imageLoaded : image(key, library)), (xmlExists ? File.getContent(modsXml(key)) : file('images/$key.xml', library)));
		#else
		return FlxAtlasFrames.fromSparrow(image(key, library), file('images/$key.xml', library));
		#end
	}


	inline static public function getPackerAtlas(key:String, ?library:String)
	{
		#if MODS_ALLOWED
		var imageLoaded:FlxGraphic = returnGraphic(key);
		var txtExists:Bool = false;
		if(FileSystem.exists(modsTxt(key))) {
			txtExists = true;
		}

		return FlxAtlasFrames.fromSpriteSheetPacker((imageLoaded != null ? imageLoaded : image(key, library)), (txtExists ? File.getContent(modsTxt(key)) : file('images/$key.txt', library)));
		#else
		return FlxAtlasFrames.fromSpriteSheetPacker(image(key, library), file('images/$key.txt', library));
		#end
	}

	inline static public function formatToSongPath(path:String) {
		var invalidChars = ~/[~&\\;:<>#]+/g;
		var hideChars = ~/[.,'"%?!]+/g;

		var path = invalidChars.split(path.replace(' ', '-')).join("-");
		return hideChars.split(path).join("").toLowerCase();
	}

	private static function regBitmap(key:String, ?hardware:Bool):BitmapData {
		hardware = hardware == null ? hardwareCache : hardware;
		
		if (OpenFlAssets.exists(key, IMAGE))
			return OpenFlAssets.getBitmapData(key, false, hardware);
		
		#if MODS_ALLOWED
		if(FileSystem.exists(key)) {
			var newBitmap:BitmapData = BitmapData.fromFile(key);
			
			if (newBitmap != null)
				return OpenFlAssets.registerBitmapData(newBitmap, key, false, hardware);
		}
		#end
		
		return null;
	}

	// completely rewritten asset loading? fuck!
	public static var hardwareCache:Bool = false;
	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];
	public static function returnGraphic(key:String, ?library:String):FlxGraphic {
		#if MODS_ALLOWED
		var modKey:String = modsImages(key);
		if(FileSystem.exists(modKey)) {
			if(!currentTrackedAssets.exists(modKey)) {
				var newGraphic:FlxGraphic = FlxGraphic.fromBitmapData(regBitmap(modKey), false, modKey);
				
				newGraphic.persist = true;
				currentTrackedAssets.set(modKey, newGraphic);
			}
			localTrackedAssets.push(modKey);
			return currentTrackedAssets.get(modKey);
		}
		#end

		var path = getPath('images/$key.png', IMAGE, library);
		if (OpenFlAssets.exists(path, IMAGE)) {
			if(!currentTrackedAssets.exists(path)) {
				var newGraphic:FlxGraphic = FlxGraphic.fromBitmapData(regBitmap(path), false, path);
				
				newGraphic.persist = true;
				currentTrackedAssets.set(path, newGraphic);
			}
			localTrackedAssets.push(path);
			return currentTrackedAssets.get(path);
		}
		trace('oh no its returning null NOOOO: ' + path);
		return null;
	};

	public static var streamSounds:Bool = false;
	public static var currentTrackedSounds:Map<String, Sound> = [];
	public static function returnSound(path:String, key:String, ?library:String, ?stream:Bool) {
		stream = stream == null ? streamSounds : stream;
		
		#if MODS_ALLOWED
		var file:String = modsSounds(path, key);
		if(FileSystem.exists(file)) {
			if(!currentTrackedSounds.exists(file)) {
				currentTrackedSounds.set(file, OpenFlAssets.getRawSound(file, stream, true));
			}
			localTrackedAssets.push(key);
			return currentTrackedSounds.get(file);
		}
		#end
		// I hate this so god damn much
		var gottenPath:String = getPath('$path/$key.$SOUND_EXT', SOUND, library);
		gottenPath = gottenPath.substring(gottenPath.indexOf(':') + 1, gottenPath.length);
		// trace(gottenPath);
		if(!currentTrackedSounds.exists(gottenPath))
		#if MODS_ALLOWED
			currentTrackedSounds.set(gottenPath, OpenFlAssets.getRawSound('./' + gottenPath, stream, true));
		#else
		{
			var folder:String = '';
			if(path == 'songs') folder = 'songs:';

			currentTrackedSounds.set(gottenPath, OpenFlAssets.getSound(folder + getPath('$path/$key.$SOUND_EXT', SOUND, library, stream)));
		}
		#end
		localTrackedAssets.push(gottenPath);
		return currentTrackedSounds.get(gottenPath);
	}

	#if MODS_ALLOWED
	inline static public function mods(key:String = '') {
		return 'mods/' + key;
	}

	inline static public function modsFont(key:String) {
		return modFolders('fonts/' + key);
	}

	inline static public function modsJson(key:String) {
		return modFolders('data/' + key + '.json');
	}

	inline static public function modsVideo(key:String) {
		return modFolders('videos/' + key + '.' + VIDEO_EXT);
	}

	inline static public function modsSounds(path:String, key:String) {
		return modFolders(path + '/' + key + '.' + SOUND_EXT);
	}

	inline static public function modsImages(key:String) {
		return modFolders('images/' + key + '.png');
	}

	inline static public function modsXml(key:String) {
		return modFolders('images/' + key + '.xml');
	}

	inline static public function modsTxt(key:String) {
		return modFolders('images/' + key + '.txt');
	}

	/* Goes unused for now

	inline static public function modsShaderFragment(key:String, ?library:String)
	{
		return modFolders('shaders/'+key+'.frag');
	}
	inline static public function modsShaderVertex(key:String, ?library:String)
	{
		return modFolders('shaders/'+key+'.vert');
	}
	inline static public function modsAchievements(key:String) {
		return modFolders('achievements/' + key + '.json');
	}*/

	static public function modFolders(key:String) {
		if(currentModDirectory != null && currentModDirectory.length > 0) {
			var fileToCheck:String = mods(currentModDirectory + '/' + key);
			if(FileSystem.exists(fileToCheck)) {
				return fileToCheck;
			}
		}

		for(mod in getGlobalMods()){
			var fileToCheck:String = mods(mod + '/' + key);
			if(FileSystem.exists(fileToCheck))
				return fileToCheck;

		}
		return 'mods/' + key;
	}

	public static var globalMods:Array<String> = [];

	static public function getGlobalMods()
		return globalMods;

	static public function pushGlobalMods() // prob a better way to do this but idc
	{
		globalMods = [];
		var path:String = 'modsList.txt';
		if(FileSystem.exists(path))
		{
			var list:Array<String> = CoolUtil.coolTextFile(path);
			for (i in list)
			{
				var dat = i.split("|");
				if (dat[1] == "1")
				{
					var folder = dat[0];
					var path = Paths.mods(folder + '/pack.json');
					if(FileSystem.exists(path)) {
						try{
							var rawJson:String = File.getContent(path);
							if(rawJson != null && rawJson.length > 0) {
								var stuff:Dynamic = Json.parse(rawJson);
								var global:Bool = Reflect.getProperty(stuff, "runsGlobally");
								if(global)globalMods.push(dat[0]);
							}
						} catch(e:Dynamic){
							trace(e);
						}
					}
				}
			}
		}
		return globalMods;
	}

	static public function getModDirectories(lowercase:Bool = false):Array<String> {
		var list:Array<String> = [];
		var modsFolder:String = mods();

		if (!FileSystem.exists(modsFolder)) return list;

		for (folder in FileSystem.readDirectory(modsFolder)) {
			var path:String = haxe.io.Path.join([modsFolder, folder]);
			var lower:String = folder.toLowerCase();
			
			if (FileSystem.isDirectory(path) && !ignoreModFolders.contains(lower) && !list.contains(lower))
				list.push(lowercase ? lower : folder);
		}

		return list;
	}
	
	static public function getActiveModDirectories(lowercase:Bool = false):Array<String> {
		var list:Array<String> = [];
		var modsFolder:String = mods();
		var path:String = 'modsList.txt';
		
		var remains:Array<String> = getModDirectories(true);
		
		if (remains.length <= 0 || !FileSystem.exists(path)) return list;
		var leMods:Array<String> = CoolUtil.coolTextFile(path);

		for (i in 0...leMods.length) {
			if (remains.length <= 0) break;
			if (leMods.length > 1 && leMods[0].length > 0) {
				var modSplit:Array<String> = leMods[i].split('|');
				var modLower:String = modSplit[0].toLowerCase();
				
				if (remains.contains(modLower) && modSplit[1] == '1') {
					remains.remove(modLower);
					list.push(lowercase ? modLower : modSplit[0]);
				}
			}
		}
		
		remains = null;
		return list;
	}
	#end
}
