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
#elseif neko
import neko.vm.Gc;
#end

using StringTools;

@:access(openfl.display.BitmapData.__texture)
class Paths {
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

	public static function excludeAsset(asset:Dynamic) {
		if ((asset is String)) {
			var key:String = asset;
			for (v in keyExclusions) if (key.endsWith(v)) return;
			keyExclusions.push(key);
			return;
		}
		if (!dumpExclusions.contains(asset)) dumpExclusions.push(asset);
	}

	public static function unexcludeAsset(asset:Dynamic) {
		if ((asset is String)) {
			var key:String = asset;
			for (v in keyExclusions) if (key.endsWith(v)) keyExclusions.remove(v);
			return;
		}
		dumpExclusions.remove(asset);
	}

	public static function assetExcluded(asset:Dynamic):Bool {
		if ((asset is String)) {
			var key:String = asset;
			for (v in keyExclusions) if (key.endsWith(v)) return true;
			return false;
		}
		for (v in dumpExclusions) if (v == asset) return true;
		return false;
	}

	public static var dumpExclusions:Array<Dynamic> = [];
	public static var keyExclusions:Array<String> = [
		'music/freakyMenu.$SOUND_EXT',
		'music/breakfast.$SOUND_EXT',
		'music/tea-time.$SOUND_EXT',
	];

	@:noCompletion private inline static function _compress():Void {
		#if cpp
		Gc.run(true);
		Gc.compact();
		#elseif hl
		Gc.major();
		#elseif neko
		Gc.run(true);
		#end
	}

	public static function compress(repeat:Int = 1):Void {
		if (repeat <= 1) return _compress();
		if (repeat > 32) repeat = 32;
		while(repeat-- > 0) _compress();
	}

	public static function decacheGraphic(key:String) {
		var obj = currentTrackedAssets.get(key);
		currentTrackedAssets.remove(key);
		@:privateAccess{
			if (obj == null) obj = FlxG.bitmap._cache.get(key);
			if (obj != null) {
				if (assetExcluded(obj)) return;

				OpenFlAssets.cache.removeBitmapData(key);
				OpenFlAssets.cache.clear(key);
				FlxG.bitmap._cache.remove(key);

				if (obj.bitmap != null) {
					obj.bitmap.lock();
					if (obj.bitmap.__texture != null) obj.bitmap.__texture.dispose();
					if (obj.bitmap.image != null) obj.bitmap.image.data = null;
					obj.bitmap.disposeImage();
				}

				obj.destroy();
			}
		}
	}

	public static function decacheSound(key:String) {
		var obj = currentTrackedSounds.get(key);
		currentTrackedSounds.remove(key);
		if (obj == null && OpenFlAssets.cache.hasSound(key)) obj = OpenFlAssets.cache.getSound(key);
		if (assetExcluded(obj)) return;

		OpenFlAssets.cache.removeSound(key);
		OpenFlAssets.cache.clear(key);

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

	public static function clearUnusedMemory() {
		for (key in currentTrackedAssets.keys()) {
			if (!localTrackedAssets.contains(key) && !assetExcluded(key))
				decacheGraphic(key);
		}

		compress(3);
	}

	// define the locally tracked assets
	public static var localTrackedAssets:Array<String> = [];
	public static function clearStoredMemory(cleanUnused:Bool = false) {
		// clear anything not in the tracked assets list
		@:privateAccess
		for (key in FlxG.bitmap._cache.keys()) {
			if (key != null && !currentTrackedAssets.exists(key) && !assetExcluded(key))
				decacheGraphic(key);
		}

		// clear all sounds that are cached
		for (key in currentTrackedSounds.keys()) {
			if (key != null && !localTrackedAssets.contains(key) 
			&& !assetExcluded(key))
				decacheSound(key);
		}

		// flags everything to be cleared out next unused memory clear
		localTrackedAssets = [];
		#if !html5 openfl.Assets.cache.clear("songs"); #end
		compress(3);
	}

	static public var currentModDirectory:String = '';
	static public var currentLevel:String;
	static public function setCurrentLevel(name:String)
		currentLevel = name.toLowerCase();

	public static function getPath(file:String, type:AssetType, ?library:String):String {
		if (library != null) return getLibraryPath(file, library);

		if (currentLevel != null) {
			var levelPath:String = '';
			if (currentLevel != 'shared') {
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
		return if (library == "preload" || library == "default") getPreloadPath(file); else getLibraryPathForce(file, library);

	inline static function getLibraryPathForce(file:String, library:String)
		return '$library:assets/$library/$file';

	inline public static function getPreloadPath(file:String = '')
		return 'assets/$file';

	inline static public function file(file:String, type:AssetType = TEXT, ?library:String)
		return getPath(file, type, library);

	inline static public function txt(key:String, ?library:String)
		return getPath('data/$key.txt', TEXT, library);

	inline static public function xml(key:String, ?library:String)
		return getPath('data/$key.xml', TEXT, library);

	inline static public function json(key:String, ?library:String)
		return getPath('data/$key.json', TEXT, library);

	inline static public function shaderFragment(key:String, ?library:String)
		return getPath('shaders/$key.frag', TEXT, library);

	inline static public function shaderVertex(key:String, ?library:String)
		return getPath('shaders/$key.vert', TEXT, library);

	inline static public function lua(key:String, ?library:String)
		return getPath('$key.lua', TEXT, library);

	#if (!MODS_ALLOWED) inline #end static public function video(key:String) {
		#if MODS_ALLOWED
		var file:String = modsVideo(key);
		if (FileSystem.exists(file)) return file;
		#end
		return 'assets/videos/$key.$VIDEO_EXT';
	}

	#if (!MODS_ALLOWED) inline #end static public function sound(key:String, ?library:String):Sound
		return returnSound('sounds', key, library);

	#if (!MODS_ALLOWED) inline #end static public function soundRandom(key:String, min:Int, max:Int, ?library:String):Sound
		return sound(key + FlxG.random.int(min, max), library);

	public static var streamMusic:Bool = false;
	#if (!MODS_ALLOWED) inline #end static public function music(key:String, ?library:String, ?stream:Bool):Sound {
		return returnSound('music', key, library,
			stream || streamMusic//stream != null ? stream : (!MusicBeatState.inState(PlayState) || streamMusic)
		);
	}

	// streamlined the assets process more
	#if (!MODS_ALLOWED) inline #end static public function image(key:String, ?library:String):FlxGraphic
		return returnGraphic(key, library);

	#if (!MODS_ALLOWED) inline #end static public function inst(song:String, ?stream:Bool, forceNoStream:Bool = false):Sound
		return returnSound('songs', '${formatToSongPath(song)}/Inst', !forceNoStream && (stream || streamMusic));

	#if (!MODS_ALLOWED) inline #end static public function voices(song:String, ?stream:Bool, forceNoStream:Bool = false):Sound
		return returnSound('songs', '${formatToSongPath(song)}/Voices', !forceNoStream && (stream || streamMusic));

	static public function getTextFromFile(key:String, ?ignoreMods:Bool = false):String {
		#if sys
		#if MODS_ALLOWED
		if (!ignoreMods && FileSystem.exists(modFolders(key)))
			return File.getContent(modFolders(key));
		#end

		if (FileSystem.exists(getPreloadPath(key)))
			return File.getContent(getPreloadPath(key));

		if (currentLevel != null) {
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

	inline static public function font(key:String):String {
		#if MODS_ALLOWED
		var file:String = modsFont(key);
		if (FileSystem.exists(file)) return file;
		#end
		return 'assets/fonts/$key';
	}

	inline static public function fileExists(key:String, type:AssetType, ?ignoreMods:Bool = false, ?onlyMods:Bool = false, ?library:String):Bool {
		#if MODS_ALLOWED
		if (!ignoreMods && (FileSystem.exists(mods(currentModDirectory + '/' + key)) || FileSystem.exists(mods(key))))
			return true;
		#end

		return !onlyMods && OpenFlAssets.exists(getPath(key, type, library), type);
	}

	inline static public function getSparrowAtlas(key:String, ?library:String):FlxAtlasFrames {
		#if MODS_ALLOWED
		var imageLoaded:FlxGraphic = returnGraphic(key);
		var xmlExists:Bool = FileSystem.exists(modsXml(key));

		return FlxAtlasFrames.fromSparrow((imageLoaded != null ? imageLoaded : image(key, library)), (xmlExists ? File.getContent(modsXml(key)) : file('images/$key.xml', library)));
		#else
		return FlxAtlasFrames.fromSparrow(image(key, library), file('images/$key.xml', library));
		#end
	}

	inline static public function getPackerAtlas(key:String, ?library:String):FlxAtlasFrames {
		#if MODS_ALLOWED
		var imageLoaded:FlxGraphic = returnGraphic(key);
		var txtExists:Bool = FileSystem.exists(modsTxt(key));

		return FlxAtlasFrames.fromSpriteSheetPacker((imageLoaded != null ? imageLoaded : image(key, library)), (txtExists ? File.getContent(modsTxt(key)) : file('images/$key.txt', library)));
		#else
		return FlxAtlasFrames.fromSpriteSheetPacker(image(key, library), file('images/$key.txt', library));
		#end
	}

	inline static public function formatToSongPath(path:String):String {
		var invalidChars = ~/[~&\\;:<>#]+/g;
		var hideChars = ~/[.,'"%?!]+/g;

		var path:String = invalidChars.split(path.replace(' ', '-')).join('-');
		return hideChars.split(path).join('').toLowerCase();
	}

	// completely rewritten asset loading? fuck!
	private static var assetCompressTrack:Int = 0;
	@:noCompletion private static function stepAssetCompress():Void {
		assetCompressTrack++;
		if (assetCompressTrack > 6) {
			assetCompressTrack = 0;
			_compress();
		}
	}

	public static var hardwareCache:Bool = false;
	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];
	public static function returnGraphic(key:String, ?library:String):FlxGraphic {
		var modExists:Bool = false, graph:FlxGraphic = null;

		#if MODS_ALLOWED
		var modKey:String = modsImages(key);
		if ((graph = currentTrackedAssets.get(modKey)) != null) {
			localTrackedAssets.push(modKey);
			return graph;
		}

		var srcKey:String = getPath('images/$key.png', IMAGE, library);
		if ((graph = currentTrackedAssets.get(srcKey)) != null) {
			//if (!(modExists = FileSystem.exists(modKey))) {
				localTrackedAssets.push(srcKey);
				return graph;
			//}
			//graph = null;
		}
		else modExists = FileSystem.exists(modKey);

		var path:String = if (modExists) modKey; else srcKey;
		#else
		var path:String = getPath('images/$key.png', IMAGE, library);
		if ((graph = currentTrackedAssets.get(path)) != null) return graph;
		#end

		if (modExists || OpenFlAssets.exists(path, IMAGE)) {
			localTrackedAssets.push(path);

			var bitmap:BitmapData = _regBitmap(path, hardwareCache, modExists);
			if (bitmap != null) graph = FlxGraphic.fromBitmapData(bitmap, false, path);

			if (graph != null) {
				graph.persist = true;
				currentTrackedAssets.set(path, graph);
				return graph;
			}
		}

		trace('oh no its returning "bitmap" null NOOOO: $path' #if MODS_ALLOWED + ' | $modKey' #end);
		return null;
	}

	private static function _regBitmap(key:String, hardware:Bool, file:Bool):BitmapData {
		stepAssetCompress();
		if (!file) return OpenFlAssets.getBitmapData(key, false, hardware);
		#if sys
		var newBitmap:BitmapData = BitmapData.fromFile(key);
		if (newBitmap != null) return OpenFlAssets.registerBitmapData(newBitmap, key, false, hardware);
		#end
		return null;
	}

	public static function regBitmap(key:String, ?hardware:Bool):BitmapData {
		if (hardware == null) hardware = hardwareCache;
		#if MODS_ALLOWED
		if (FileSystem.exists(key)) return _regBitmap(key, hardware, true);
		#end
		if (OpenFlAssets.exists(key, IMAGE)) return _regBitmap(key, hardware, false);
		return null;
	}

	public static var streamSounds:Bool = false;
	public static var currentTrackedSounds:Map<String, Sound> = [];
	public static function returnSound(path:String, key:String, ?library:String, ?stream:Bool):Sound {
		#if MODS_ALLOWED
		var modKey:String = modsSounds(path, key), modExists:Bool = FileSystem.exists(modKey);
		var path:String = if (modExists) modKey; else getPath('$path/$key.$SOUND_EXT', SOUND, library);
		var track:String = path.substr(path.indexOf(':') + 1);
		var folder:String = './';
		#else
		var path:String = getPath('$path/$key.$SOUND_EXT', IMAGE, library), modExists:Bool = false;
		var track:String = path.substr(path.indexOf(':') + 1);
		var folder:String = '';
		if (path == 'songs') folder = 'songs:';
		#end
		var uwu:String = folder + (modExists ? path : track);

		#if (!MODS_ALLOWED)
		if (OpenFlAssets.exists(uwu, SOUND)) {
		#end
			localTrackedAssets.push(track);
			var sound:Sound = currentTrackedSounds.get(track);

			// if no stream and sound is stream, fuck it, load one that arent stream
			@:privateAccess if (!stream && sound != null && sound.__buffer != null && sound.__buffer.__srcVorbisFile != null) {
				decacheSound(track);
				sound = null;
			}
			if (sound == null) currentTrackedSounds.set(track, sound = _regSound(uwu, stream, #if MODS_ALLOWED true #else modExists #end));
			if (sound != null) return sound;
		#if (!MODS_ALLOWED) } #end

		trace('oh no its returning "sound" null NOOOO: $path' #if MODS_ALLOWED + ' | $modKey' #end);
		return null;
	}

	private static function _regSound(key:String, stream:Bool, file:Bool):Sound {
		var snd:Sound = OpenFlAssets.getRawSound(key, stream, file);
		if (snd == null) stepAssetCompress();
		return snd;
	}

	public static function regSound(key:String, ?stream:Bool):Sound {
		if (stream == null) stream = streamSounds;
		#if MODS_ALLOWED
		if (FileSystem.exists(key)) return _regSound(key, stream, true);
		#end
		if (OpenFlAssets.exists(key, SOUND)) return _regSound(key, stream, false);
		return null;
	}

	#if MODS_ALLOWED
	inline static public function mods(key:String = '')
		return 'mods/' + key;

	inline static public function modsFont(key:String)
		return modFolders('fonts/' + key);

	inline static public function modsJson(key:String)
		return modFolders('data/' + key + '.json');

	inline static public function modsVideo(key:String)
		return modFolders('videos/' + key + '.' + VIDEO_EXT);

	inline static public function modsSounds(path:String, key:String)
		return modFolders(path + '/' + key + '.' + SOUND_EXT);

	inline static public function modsImages(key:String)
		return modFolders('images/' + key + '.png');

	inline static public function modsXml(key:String)
		return modFolders('images/' + key + '.xml');

	inline static public function modsTxt(key:String)
		return modFolders('images/' + key + '.txt');

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
		var file;
		if (currentModDirectory != null && currentModDirectory.length > 0) {
			file = mods(currentModDirectory + '/' + key);
			if (FileSystem.exists(file)) return file;
		}

		for (mod in getGlobalMods()) {
			file = mods(mod + '/' + key);
			if (FileSystem.exists(file)) return file;
		}
		return mods(key);
	}

	public static var globalMods:Array<String> = [];
	static public function getGlobalMods()
		return globalMods;

	static public function pushGlobalMods() { // prob a better way to do this but idc
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

	static public function isValidModDir(dir:String):Bool
		return FileSystem.isDirectory(haxe.io.Path.join([mods(), dir])) && !ignoreModFolders.contains(dir.toLowerCase());

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
