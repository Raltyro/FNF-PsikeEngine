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
	private var curBPMChange:BPMChangeEvent;

	private var passedSections:Array<Float> = [];
	private var stepsToDo:Float = 0;
	private var curSection:Int = 0;
	private var prevSection:Int = 0;

	private var curDecStep:Float = 0;
	private var curStep:Int = 0;
	private var prevDecStep:Float = 0;
	private var prevStep:Int = 0;

	private var curDecBeat:Float = 0;
	private var curBeat:Int = 0;
	private var prevDecBeat:Float = 0;
	private var prevBeat:Int = 0;

	private var controls(get, never):Controls;

	private var stateClass:Class<MusicBeatState>;
	private var isPlayState:Bool;

	private static var previousStateClass:Class<FlxState>;
	public static var camBeat:FlxCamera;

	inline function get_controls():Controls
		return PlayerSettings.player1.controls;

	public function new() {
		curBPMChange = Conductor.getDummyBPMChange();
		super();
	}

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

		Paths.compress(2);
		persistentUpdate = false;
		previousStateClass = cast Type.getClass(this);
		passedSections = null;
	}

	override function update(elapsed:Float):Void {
		prevDecStep = curDecStep;
		prevStep = curStep;

		prevDecBeat = curDecBeat;
		prevBeat = curBeat;

		updateCurStep();
		updateBeat();

		if (prevStep != curStep) {
			if (curStep > 0 || !isPlayState) stepHit();

			if (prevStep < curStep)
				updateSection();
			else
				rollbackSection();
		}

		if (FlxG.save.data != null) FlxG.save.data.fullscreen = FlxG.fullscreen;
		super.update(elapsed);
	}

	private function updateSection(dontHit:Bool = false):Void {
		var steps = getBeatsOnSection() * 4;
		if (stepsToDo <= steps) {
			curSection = 0;
			stepsToDo = steps;
			passedSections.resize(0);
		}

		while(curStep >= stepsToDo) {
			passedSections.push(stepsToDo);
			stepsToDo += steps;
			steps = getBeatsOnSection() * 4;

			prevSection = curSection;
			curSection++;
			if (!dontHit) sectionHit();
		}
	}

	private function rollbackSection():Void {
		var lastSection = curSection;

		var prevSteps;
		while(passedSections.length > 0) {
			if (stepsToDo < passedSections[0]) {
				updateSection(false);
				if (curSection > lastSection || !isPlayState) sectionHit();
				return;
			}
			prevSteps = passedSections[passedSections.length];

			if (prevSteps < stepsToDo) break;
			passedSections.pop();
			stepsToDo -= prevSteps;
			curSection--;
		}
		if (curSection > lastSection) sectionHit();
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
		if (curStep % 4 == 0) beatHit();
	}

	public function beatHit():Void {
		//trace('Beat: ' + curBeat);
	}

	public function sectionHit():Void {
		//trace('Section: ' + curSection + ', Beat: ' + curBeat + ', Step: ' + curStep);
	}

	public function getBeatsOnSection():Float {
		return inline Conductor.getSectionBeats(PlayState.SONG, curSection);
	}
}
