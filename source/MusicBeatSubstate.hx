package;

import flixel.FlxSubState;
import flixel.FlxG;

import Conductor.BPMChangeEvent;

class MusicBeatSubstate extends FlxSubState {
	private var curBPMChange:BPMChangeEvent;

	private var curDecStep:Float = 0;
	private var curStep:Int = 0;
	private var prevDecStep:Float = 0;
	private var prevStep:Int = 0;

	private var curDecBeat:Float = 0;
	private var curBeat:Int = 0;
	private var prevDecBeat:Float = 0;
	private var prevBeat:Int = 0;

	private var controls(get, never):Controls;

	inline function get_controls():Controls
		return PlayerSettings.player1.controls;

	public function new() {
		curBPMChange = Conductor.getDummyBPMChange();
		super();
	}

	override function update(elapsed:Float) {
		prevDecStep = curDecStep;
		prevStep = curStep;

		prevDecBeat = curDecBeat;
		prevBeat = curBeat;

		updateCurStep();
		updateBeat();

		if (prevStep != curStep) stepHit();

		super.update(elapsed);
	}

	private function updateBeat():Void {
		curDecBeat = curDecStep / 4;
		curBeat = Math.floor(curDecBeat);
	}

	private function updateCurStep():Void {
		var rawSongPos = Conductor.songPosition - ClientPrefs.noteOffset;

		curBPMChange = Conductor.getBPMFromSeconds(rawSongPos, curBPMChange != null ? curBPMChange.id : -1);
		curDecStep = Conductor.getStep(rawSongPos, curBPMChange.id);
		curStep = Math.floor(curDecStep);
	}

	public function stepHit():Void
		if (curStep % 4 == 0) beatHit();

	public function beatHit():Void {
		//trace('Beat: ' + curBeat);
	}
}
