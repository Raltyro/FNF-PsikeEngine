package;

import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.ui.FlxUIState;
import flixel.FlxState;
import flixel.FlxCamera;
import flixel.FlxG;

import Conductor.BPMChangeEvent;

class MusicBeatState extends FlxUIState {
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
		isPlayState = (stateClass = Type.getClass(this)) == PlayState;
		curBPMChange = Conductor.getDummyBPMChange();

		super();
	}

	override function create() {
		if (curBPMChange.bpm != Conductor.bpm) curBPMChange = Conductor.getDummyBPMChange();
		var skip = FlxTransitionableState.skipNextTransOut;
		camBeat = FlxG.camera;

		super.create();

		if (!skip) openSubState(new CustomFadeTransition(0.7, true));
		FlxTransitionableState.skipNextTransOut = false;
	}

	override function destroy() {
		previousStateClass = cast stateClass;
		persistentUpdate = false;
		passedSections = null;
		Paths.compress(2);

		super.destroy();
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
			if (passedSections == null) passedSections = [];
			if (curStep > prevStep)
				updateSection();
			else
				rollbackSection();
		}

		if (FlxG.save.data != null) FlxG.save.data.fullscreen = FlxG.fullscreen;
		super.update(elapsed);
	}

	private function updateSection(?dontHit:Bool = false):Void {
		if (stepsToDo <= 0) {
			curSection = 0;
			stepsToDo = getBeatsOnSection() * 4;
			passedSections.resize(0);
		}

		while(curStep >= stepsToDo) {
			passedSections.push(stepsToDo);
			stepsToDo = stepsToDo + getBeatsOnSection() * 4;

			prevSection = curSection;
			curSection = passedSections.length;
			if (!dontHit) sectionHit();
		}
	}

	private function rollbackSection():Void {
		if (curStep <= 0) {
			stepsToDo = 0;
			return updateSection();
		}

		var lastSection = prevSection = curSection;
		while((curSection = passedSections.length) > 0 && curStep < passedSections[curSection - 1])
			stepsToDo = passedSections.pop();

		if (curSection > lastSection) sectionHit();
	}

	private function updateBeat():Void {
		curDecBeat = curDecStep / 4;
		curBeat = Math.floor(curDecBeat);
	}

	private function updateCurStep():Void {
		curBPMChange = Conductor.getBPMFromSeconds(Conductor.songPosition, curBPMChange != null ? curBPMChange.id : -1);
		curDecStep = Conductor.getStep(Conductor.songPosition, ClientPrefs.noteOffset, curBPMChange.id);
		curStep = Math.floor(curDecStep);
	}

	public function getBeatsOnSection():Float
		return inline Conductor.getSectionBeats(PlayState.SONG, curSection);

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
		nextState = Type.createInstance(Type.getClass(FlxG.state), []);
		postSwitchState();
	}

	private static function postSwitchState() {
		FlxTransitionableState.skipNextTransIn = false;
		CustomFadeTransition.finishCallback = null;

		FlxG.state.switchTo(nextState);
		@:privateAccess FlxG.game._requestedState = nextState;
		nextState = null;
	}

	public static function resetState()
		MusicBeatState.switchState(null, true);

	public static function getState(?state:FlxState):MusicBeatState
		return cast(state != null ? state : FlxG.state);

	public static function isState(state1:FlxState, state2:Class<FlxState>):Bool
		return Std.isOfType(state1, state2);

	public static function inState(state:Class<FlxState>):Bool
		return inline isState(FlxG.state, state);

	public static function previousStateIs(state:Class<FlxState>):Bool
		return previousStateClass == state;

	public function stepHit():Void {
		if (curStep % 4 == 0) beatHit();
	}

	public function beatHit():Void {
		//trace('Beat: ' + curBeat);
	}

	public function sectionHit():Void {
		//trace('Section: ' + curSection + ', Beat: ' + curBeat + ', Step: ' + curStep);
	}
}
