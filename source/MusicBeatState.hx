package;

import Conductor.BPMChangeEvent;
import flixel.FlxG;
import flixel.addons.ui.FlxUIState;
import flixel.math.FlxRect;
import flixel.util.FlxTimer;
import flixel.addons.transition.FlxTransitionableState;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import flixel.util.FlxGradient;
import flixel.FlxState;
import flixel.FlxCamera;
import flixel.FlxBasic;

class MusicBeatState extends FlxUIState
{
	private var curSection:Int = 0;
	private var stepsToDo:Int = 0;

	private var curStep:Int = 0;
	private var curBeat:Int = 0;

	private var curDecStep:Float = 0;
	private var curDecBeat:Float = 0;
	private var controls(get, never):Controls;

	private var stateClass:Class<MusicBeatState>;
	private var isPlayState:Bool;

	private static var previousStateClass:Class<FlxState>;
	public static var camBeat:FlxCamera;

	inline function get_controls():Controls
		return PlayerSettings.player1.controls;

	override function create() {
		var skip:Bool = FlxTransitionableState.skipNextTransOut;
		camBeat = FlxG.camera;
		super.create();

		if (!skip) openSubState(new CustomFadeTransition(0.7, true));
		FlxTransitionableState.skipNextTransOut = false;
		isPlayState = inState(PlayState);
		stateClass = Type.getClass(this);
	}

	override function destroy() {
		super.destroy();

		active = false;
		Paths.compress(2);
		persistentUpdate = false;
		previousStateClass = cast Type.getClass(this);
	}

	override function update(elapsed:Float):Void {
		var oldStep:Int = curStep;
		updateCurStep();
		updateBeat();

		if (oldStep != curStep) {
			if (curStep > 0 || !isPlayState) stepHit();

			if (oldStep < curStep)
				updateSection();
			else
				rollbackSection();
		}

		if (FlxG.save.data != null) FlxG.save.data.fullscreen = FlxG.fullscreen;
		super.update(elapsed);
	}

	private function updateSection():Void {
		if (stepsToDo < 1) stepsToDo = Math.round(getBeatsOnSection() * 4);
		while (curStep >= stepsToDo) {
			curSection++;

			stepsToDo += Math.round(getBeatsOnSection() * 4);
			sectionHit();
		}
	}

	private function rollbackSection():Void {
		if (curStep < 0 && isPlayState) return;
		curSection = 0;
		stepsToDo = 0;

		if (PlayState.SONG != null) {
			var lastSection = curSection;
			for (i in 0...PlayState.SONG.notes.length) {
				if (PlayState.SONG.notes[i] != null) {
					stepsToDo += Math.round(getBeatsOnSection() * 4);
					if (stepsToDo > curStep) break;

					curSection++;
				}
			}

			if (curSection > lastSection) sectionHit();
		}
		else {
			sectionHit();
			updateSection();
		}
	}

	private function updateBeat():Void {
		curDecBeat = curDecStep / 4;
		curBeat = Math.floor(curDecBeat);
	}

	private function updateCurStep():Void {
		var lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);

		var shit = ((Conductor.songPosition - ClientPrefs.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		curDecStep = lastChange.stepTime + shit;
		curStep = lastChange.stepTime + Math.floor(shit);
	}

	private static var nextState:FlxState;
	public static function switchState(nextState:FlxState, reset:Bool = false) {
		reset = reset ? reset : inState(Type.getClass(nextState));

		MusicBeatState.nextState = nextState;
		if (FlxTransitionableState.skipNextTransIn) return reset ? postResetState() : postSwitchState();

		// Custom made Trans in
		var state:MusicBeatState = getState();
		CustomFadeTransition.finishCallback = reset ? postResetState : postSwitchState;
		state.openSubState(new CustomFadeTransition(0.6, false));
	}

	private static function postResetState() {
		FlxTransitionableState.skipNextTransIn = false;
		CustomFadeTransition.finishCallback = null;

		FlxG.state.persistentUpdate = false;
		FlxG.resetState();
	}

	private static function postSwitchState() {
		FlxTransitionableState.skipNextTransIn = false;
		CustomFadeTransition.finishCallback = null;

		FlxG.state.persistentUpdate = false;
		FlxG.switchState(nextState);
		nextState = null;
	}

	public static function resetState() {
		MusicBeatState.switchState(null, true);
	}

	public static function getState(?state:FlxState):MusicBeatState {
		return cast(state != null ? state : FlxG.state);
	}

	public static function inState(state:Class<FlxState>):Bool {
		return Std.isOfType(FlxG.state, state);
	}

	public static function previousStateIs(state:Class<FlxState>):Bool {
		return previousStateClass != null && previousStateClass == state;
	}

	public function stepHit():Void {
		if (curStep % 4 == 0)
			beatHit();
	}

	public function beatHit():Void {
		//trace('Beat: ' + curBeat);
	}

	public function sectionHit():Void {
		//trace('Section: ' + curSection + ', Beat: ' + curBeat + ', Step: ' + curStep);
	}

	public function getBeatsOnSection():Float {
		var v:Null<Float> = (PlayState.SONG == null || PlayState.SONG.notes[curSection] == null)
			? null : PlayState.SONG.notes[curSection].sectionBeats;
		return v == null ? 4 : v;
	}
}
