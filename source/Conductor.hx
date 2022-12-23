package;

import flixel.util.FlxSort;

import Song.SwagSong;

/**
 * ...
 * @author
 */

typedef BPMChangeEvent = {
	var stepTime:Int;
	var songTime:Float;
	var bpm:Float;
	var ?stepCrochet:Float;
	var ?id:Int; // is calculated in mapBPMChanges()
}

class Conductor {
	public static var bpm:Float = 100;
	public static var crochet:Float = calculateCrochet(bpm); // beats in milliseconds
	public static var stepCrochet:Float = crochet / 4; // steps in milliseconds
	public static var songPosition:Float = 0;
	public static var lastSongPos:Float;

	public static var safeZoneOffset:Float = (ClientPrefs.safeFrames / 60) * 1000; // is calculated in create(), is safeFrames in milliseconds
	public static var offset:Float = 0;

	public static var bpmChangeMap:Array<BPMChangeEvent> = [];

	public function new() {}

	inline public static function calculateCrochet(bpm:Float):Float
		return (60 / bpm) * 1000;

	public static function judgeNote(note:Note, diff:Float = 0):Rating {
		var data = PlayState.instance.ratingsData; //shortening cuz fuck u
		for (i in 0...data.length-1) { //skips last window (Shit)
			if (diff <= data[i].hitWindow)
				return data[i];
		}
		return data[data.length - 1];
	}

	public inline static function getDummyBPMChange():BPMChangeEvent {
		return {
			stepTime: 0,
			songTime: 0,
			bpm: bpm,
			stepCrochet: stepCrochet,
			id: -1
		};
	}

	private static function sortBPMChangeMap():Void {
		bpmChangeMap.sort((v1, v2) -> (v1.songTime > v2.songTime ? 1 : -1));
		for (i in 0...bpmChangeMap.length) bpmChangeMap[i].id = i;
	}

	public static function getBPMFromIndex(index:Int):BPMChangeEvent {
		var map = bpmChangeMap[index];
		if (map == null) return getDummyBPMChange();
		if (map.id == index) return map;

		sortBPMChangeMap(); map = bpmChangeMap[index];
		return map == null ? getDummyBPMChange() : map;
	}

	// just wanted to lyk, these arent acctualy seconds, its ms! same goes for the functions below
	public static function getBPMFromSeconds(time:Float, ?from:Int = -1):BPMChangeEvent {
		var lastChange = getBPMFromIndex(from), reverse = lastChange.songTime > time;
		from = lastChange.id;

		var i = from >= 0 ? from : reverse ? bpmChangeMap.length : -1, v;
		while (reverse ? --i >= 0 : ++i < bpmChangeMap.length) {
			v = bpmChangeMap[i];

			if (v.id != i) {sortBPMChangeMap(); return getBPMFromSeconds(time);}
			if (reverse ? v.songTime <= time : v.songTime >= time) break;
			lastChange = v;
		}
		return lastChange;
	}

	public static function getBPMFromStep(step:Float, ?from:Int = -1):BPMChangeEvent {
		var lastChange = getBPMFromIndex(from), reverse = lastChange.stepTime > step;
		from = lastChange.id;

		var i = from >= 0 ? from : reverse ? bpmChangeMap.length : -1, v;
		while (reverse ? --i >= 0 : ++i < bpmChangeMap.length) {
			v = bpmChangeMap[i];

			if (v.id != i) {sortBPMChangeMap(); return getBPMFromStep(step);}
			if (reverse ? v.stepTime <= step : v.stepTime >= step) break;
			lastChange = v;
		}
		return lastChange;
	}

	public static function getCrotchetAtTime(time:Float, ?from:Int = -1):Float
		return getBPMFromSeconds(time, from).stepCrochet * 4;

	public static function stepToSeconds(step:Float, ?from:Int = -1):Float {
		var lastChange = getBPMFromStep(step, from);
		return lastChange.songTime + (step - lastChange.stepTime) * lastChange.stepCrochet;
	}

	public static function beatToSeconds(beat:Float, ?from:Int = -1):Float
		return inline stepToSeconds(beat * 4, from);

	public static function getStep(time:Float, ?from:Int = -1):Float {
		var lastChange = getBPMFromSeconds(time, from);
		return lastChange.stepTime + (time - lastChange.songTime) / lastChange.stepCrochet;
	}

	public static function getStepRounded(time:Float, ?from:Int = -1):Int
		return Math.floor(inline getStep(time, from));

	public static function getBeat(time:Float, ?from:Int = -1):Float
		return (inline getStep(time, from)) / 4;

	public static function getBeatRounded(time:Float, ?from:Int = -1):Int
		return Math.floor(inline getBeat(time, from));

	public static function mapBPMChanges(song:SwagSong) {
		bpmChangeMap = [];

		var curBPM:Float = song.bpm;
		var totalPos:Float = 0, totalSteps:Int = 0, totalBPM:Int = 0;

		var deltaSteps, v;
		for (i in 0...song.notes.length) {
			v = song.notes[i];

			if (v.changeBPM && v.bpm != curBPM) {
				bpmChangeMap.push({
					stepTime: totalSteps,
					songTime: totalPos,
					bpm: curBPM,
					stepCrochet: calculateCrochet(curBPM) / 4,
					id: totalBPM++
				});
			}
			curBPM = v.bpm;

			deltaSteps = Math.round(getSectionBeats(song, i) * 4);
			totalPos += (calculateCrochet(curBPM) / 4) * deltaSteps;
			totalSteps += deltaSteps;
		}

		trace("new BPM map BUDDY " + bpmChangeMap);
	}

	public static function getSectionBeats(song:SwagSong, section:Int):Float {
		var v:Null<Float> = (song == null || song.notes[section] == null) ? null : song.notes[section].sectionBeats;
		return (v == null) ? 4 : v;
	}

	public static function changeBPM(newBpm:Float) {
		bpm = newBpm;

		crochet = calculateCrochet(bpm);
		stepCrochet = crochet / 4;
	}
}

class Rating {
	public var name:String = '';
	public var image:String = '';
	public var counter:String = '';
	public var hitWindow:Null<Int> = 0; //ms
	public var ratingMod:Float = 1;
	public var score:Int = 350;
	public var noteSplash:Bool = true;

	public function new(name:String) {
		this.name = name;
		this.image = name;
		this.counter = name + 's';
		this.hitWindow = Reflect.field(ClientPrefs, name + 'Window');
		if (hitWindow == null) {
			hitWindow = 0;
		}
	}

	public function increase(blah:Int = 1) {
		Reflect.setField(PlayState.instance, counter, Reflect.field(PlayState.instance, counter) + blah);
	}
}
