package;

import haxe.Json;

import lime.utils.Assets;

import openfl.utils.Assets as OpenFlAssets;
import openfl.events.KeyboardEvent;
import openfl.display.BitmapData;
import openfl.Lib;

import flixel.addons.effects.FlxTrail;
import flixel.addons.effects.FlxTrailArea;
import flixel.addons.effects.chainable.FlxEffectSprite;
import flixel.addons.effects.chainable.FlxWaveEffect;
import flixel.addons.transition.FlxTransitionableState;
import flixel.animation.FlxAnimationController;
import flixel.effects.particles.FlxEmitter;
import flixel.effects.particles.FlxParticle;
import flixel.input.gamepad.FlxGamepad;
import flixel.input.keyboard.FlxKey;
import flixel.util.FlxStringUtil;
import flixel.util.FlxCollision;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import flixel.util.FlxTimer;
import flixel.util.FlxSave;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.tweens.misc.VarTween;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxBar;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.graphics.FlxGraphic;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.FlxSubState;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.FlxObject;
import flixel.FlxBasic;
import flixel.FlxGame;
import flixel.FlxG;

import animateatlas.AtlasFrameMaker;
import editors.CharacterEditorState;
import editors.ChartingState;

import Section.SwagSection;
import WiggleEffect.WiggleEffectType;
import Conductor.Rating;
import Note.EventNote;
import Song.SwagSong;

import DialogueBoxPsych;
import Achievements;
import StageData;
import FunkinLua;

#if !flash 
import flixel.addons.display.FlxRuntimeShader;
import openfl.filters.ShaderFilter;
#end

#if sys
import sys.FileSystem;
import sys.io.File;
#end

#if desktop
import Discord.DiscordClient;
#end

#if VIDEOS_ALLOWED
import VideoHandler;
#end

import WindowUtil;

using StringTools;

class PlayState extends MusicBeatState
{
	public static var STRUM_X = 42;
	public static var STRUM_X_MIDDLESCROLL = -278;

	public static var ratingStuff:Array<Dynamic> = [
		['You Suck!', 0.2], //From 0% to 19%
		['Shit', 0.4], //From 20% to 39%
		['Bad', 0.5], //From 40% to 49%
		['Bruh', 0.6], //From 50% to 59%
		['Meh', 0.69], //From 60% to 68%
		['Nice', 0.7], //69%
		['Good', 0.8], //From 70% to 79%
		['Great', 0.9], //From 80% to 89%
		['Sick!', 1], //From 90% to 99%
		['Perfect!!', 1] //The value on this one isn't used actually, since Perfect is always "1"
	];

	// how big to stretch the pixel art assets
	public static var daPixelZoom:Float = 6;

	// Statics
	public static var instance:PlayState;

	public static var campaignScore:Int = 0;
	public static var campaignMisses:Int = 0;
	public static var deathCounter:Int = 0;

	public static var isStoryMode:Bool = false;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];
	public static var storyDifficulty:Int = 1;

	public static var chartingMode:Bool = false;

	public static var seenCutscene:Bool = false;
	public static var changedDifficulty:Bool = false;
	public static var restarted:Bool = false;

	// Song
	public static var SONG:SwagSong = null;
	public static var curStage:String = '';
	public static var isPixelStage:Bool = false;

	public var songLength:Float = 0;
	private var curSong:String = "";

	// Precache
	public var precacheList:Map<String, String> = new Map<String, String>();
	public var boyfriendMap:Map<String, Boyfriend> = new Map();
	public var dadMap:Map<String, Character> = new Map();
	public var gfMap:Map<String, Character> = new Map();

	//event variables
	private var isCameraOnForcedPos:Bool = false;

	// Debug buttons
	private var debugKeysChart:Array<FlxKey>;
	private var debugKeysCharacter:Array<FlxKey>;

	// Luas
	public var variables:Map<String, Dynamic> = new Map();
	public var modchartTweens:Map<String, FlxTween> = new Map<String, FlxTween>();
	public var modchartSprites:Map<String, ModchartSprite> = new Map<String, ModchartSprite>();
	public var modchartTimers:Map<String, FlxTimer> = new Map<String, FlxTimer>();
	public var modchartSounds:Map<String, FlxSound> = new Map<String, FlxSound>();
	public var modchartTexts:Map<String, ModchartText> = new Map<String, ModchartText>();
	public var modchartSaves:Map<String, FlxSave> = new Map<String, FlxSave>();

	public var luaDebugGroup:FlxTypedGroup<DebugLuaText>;
	public var luaArray:Array<FunkinLua> = [];

	// Controls
	public var strumsBlocked:Array<Bool> = [];
	public var keysPressed:Array<Bool> = [];

	private var singAnimations:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];
	private var controlArray:Array<String> = ['NOTE_LEFT', 'NOTE_DOWN', 'NOTE_UP', 'NOTE_RIGHT'];
	private var keysArray:Array<Dynamic>;

	// Gameplay settings
	public var playbackRate(default, set):Float = 1;

	public var healthGain:Float = 1;
	public var healthLoss:Float = 1;
	public var instakillOnMiss:Bool = false;
	public var cpuControlled:Bool = false;
	public var practiceMode:Bool = false;

	// Gameplay
	public var songSpeedTween:FlxTween;
	public var songSpeed(default, set):Float = 1;
	public var songSpeedType:String = "multiplicative";

	public var sustainScoreMult:Float = 1 / 8;
	public var noteKillOffset:Float = 350;
	public var spawnTime:Float = 2000;

	// Camera
	private static var prevCamFollow:FlxPoint;
	private static var prevCamFollowPos:FlxObject;

	public var camFollow:FlxPoint;
	public var camFollowPos:FlxObject;

	public var camGame:FlxCamera;
	public var camHUD:FlxCamera;
	public var camOther:FlxCamera;

	public var defaultCamZoom:Float = 1.05;
	public var cameraSpeed:Float = 1;

	public var canTweenCamZoom:Bool = false;
	public var canTweenCamZoomBoyfriend:Float = 1;
	public var canTweenCamZoomDad:Float = 1;
	public var canTweenCamZoomGf:Float = 1.3;

	public var dontZoomCam:Bool = false;
	public var camZooming:Bool = false;
	public var camZoomingMult:Float = 1;
	public var camZoomingDecay:Float = 1;

	// Notes
	public var generatedMusic:Bool = false;

	public var notes:FlxTypedGroup<Note>;
	public var unspawnNotes:Array<Note> = [];
	public var eventNotes:Array<EventNote> = [];

	public var strumLineNotes:FlxTypedGroup<StrumNote>;
	public var opponentStrums:FlxTypedGroup<StrumNote>;
	public var playerStrums:FlxTypedGroup<StrumNote>;
	public var grpNoteSplashes:FlxTypedGroup<NoteSplash>;

	private var strumLine:FlxSprite;

	// HUD
	public var songPercent:Float = 0;
	public var updateTime:Bool = true;
	public var timeBarBG:AttachedSprite;
	public var timeBar:FlxBar;
	public var timeTxt:FlxText;

	public var healthBarBG:AttachedSprite;
	public var healthBar:FlxBar;

	public var scoreTxt:FlxText;
	var scoreTxtTween:FlxTween;

	public var botplaySine:Float = 0;
	public var botplayTxt:FlxText;

	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;

	// PlayState
	public var introSoundsSuffix:String = '';
	public var boyfriendCameraOffset:Array<Float> = null;
	public var opponentCameraOffset:Array<Float> = null;
	public var girlfriendCameraOffset:Array<Float> = null;

	public var boyfriendGroup:FlxSpriteGroup;
	public var dadGroup:FlxSpriteGroup;
	public var gfGroup:FlxSpriteGroup;

	public var dad:Character;
	public var gf:Character;
	public var boyfriend:Boyfriend;
	public var gameOverChar:Boyfriend;

	public var vocals:FlxSound;

	public var BF_X:Float = 770;
	public var BF_Y:Float = 100;
	public var DAD_X:Float = 100;
	public var DAD_Y:Float = 100;
	public var GF_X:Float = 400;
	public var GF_Y:Float = 130;

	public var gfSpeed:Int = 1;

	public var firstStart:Bool = false;

	public var inCutscene:Bool = false;
	public var skipCountdown:Bool = false;

	public var endingSong:Bool = false;
	public var startingSong:Bool = false;

	public var lightShutOffStart:Bool = false;
	public var lightShutOffEnd:Bool = false;
	public var lightShutOffColor:FlxColor = FlxColor.WHITE;
	public var lightShutOffStartDelay:Float = .1;
	public var lightShutOffStartDuration:Float = 1;
	public var lightShutOffStartComplete:Void->Void;

	// Scores
	public var songScore:Int = 0;
	public var songHits:Int = 0;
	public var songMisses:Int = 0;

	public var health:Float = 1;

	public var ratingsData:Array<Rating> = [];
	public var combo:Int = 0;
	public var sicks:Int = 0;
	public var goods:Int = 0;
	public var bads:Int = 0;
	public var shits:Int = 0;

	// Achievement shit
	private var keysUsed:Array<Bool> = [];
	private var boyfriendIdleTime:Float = 0.0;
	private var boyfriendIdled:Bool = false;

	// Dialogues
	public var dialogue:Array<String> = ['blah blah blah', 'coolswag'];
	public var dialogueJson:DialogueFile = null;

	#if desktop // Discord RPC variables
	var storyDifficultyText:String = "";
	var detailsPausedText:String = "";
	var detailsText:String = "";
	#end

	var dadbattleBlack:BGSprite;
	var dadbattleLight:BGSprite;
	var dadbattleSmokes:FlxSpriteGroup;

	var halloweenBG:BGSprite;
	var halloweenWhite:BGSprite;

	var phillyLightsColors:Array<FlxColor>;
	var phillyWindow:BGSprite;
	var phillyStreet:BGSprite;
	var phillyTrain:BGSprite;
	var blammedLightsBlack:FlxSprite;
	var phillyWindowEvent:BGSprite;
	var trainSound:FlxSound;

	var phillyGlowGradient:PhillyGlow.PhillyGlowGradient;
	var phillyGlowParticles:FlxTypedGroup<PhillyGlow.PhillyGlowParticle>;

	var limoKillingState:Int = 0;
	var limo:BGSprite;
	var limoMetalPole:BGSprite;
	var limoLight:BGSprite;
	var limoCorpse:BGSprite;
	var limoCorpseTwo:BGSprite;
	var bgLimo:BGSprite;
	var grpLimoParticles:FlxTypedGroup<BGSprite>;
	var grpLimoDancers:FlxTypedGroup<BackgroundDancer>;
	var fastCar:BGSprite;

	var upperBoppers:BGSprite;
	var bottomBoppers:BGSprite;
	var santa:BGSprite;
	var heyTimer:Float;

	var bgGirls:BackgroundGirls;
	var wiggleShit:WiggleEffect = new WiggleEffect();
	var bgGhouls:BGSprite;

	var tankWatchtower:BGSprite;
	var tankGround:BGSprite;
	var tankmanRun:FlxTypedGroup<TankmenBG>;
	var foregroundSprites:FlxTypedGroup<BGSprite>;

	override function create() {
		instance = this;

		firstStart = !MusicBeatState.previousStateIs(PlayState);
		FlxG.fixedTimestep = false;
		persistentUpdate = true;
		persistentDraw = true;

		// Clean-up
		Conductor.songPosition = Math.NEGATIVE_INFINITY;
		if (firstStart) FlxG.sound.destroy(true);
		Paths.clearStoredMemory();

		// Random ass fix for previous playstate still exists to my ass uwu
		if (FlxG.sound.music != null) FlxG.sound.music.destroy();
		var music:FlxSound = FlxG.sound.music = new FlxSound();
		music.group = FlxG.sound.defaultMusicGroup;
		music.persist = true;
		music.volume = 1;

		#if LUA_ALLOWED
		FunkinLua.initStatics();
		#end

		// Reset to defaults
		GameOverSubstate.resetVariables();
		PauseSubState.songName = null;

		// Controls
		debugKeysChart = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1'));
		debugKeysCharacter = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_2'));

		keysArray = [
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_left')),
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_down')),
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_up')),
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_right'))
		];

		fillKeysPressed();

		// Ratings
		ratingsData.push(new Rating('sick')); //default rating

		var rating:Rating = new Rating('good');
		rating.ratingMod = 0.7;
		rating.score = 200;
		rating.noteSplash = false;
		ratingsData.push(rating);

		var rating:Rating = new Rating('bad');
		rating.ratingMod = 0.4;
		rating.score = 100;
		rating.noteSplash = false;
		ratingsData.push(rating);

		var rating:Rating = new Rating('shit');
		rating.ratingMod = 0;
		rating.score = 50;
		rating.noteSplash = false;
		ratingsData.push(rating);

		// Gameplay settings
		healthGain = ClientPrefs.getGameplaySetting('healthgain', 1);
		healthLoss = ClientPrefs.getGameplaySetting('healthloss', 1);
		instakillOnMiss = ClientPrefs.getGameplaySetting('instakill', false);
		practiceMode = ClientPrefs.getGameplaySetting('practice', false);
		cpuControlled = ClientPrefs.getGameplaySetting('botplay', false);
		playbackRate = ClientPrefs.getGameplaySetting('songspeed', 1);

		// Cameras
		camGame = new FlxCamera();
		camHUD = new FlxCamera();
		camOther = new FlxCamera();
		camGame.bgColor = 0xFF000000;
		camHUD.bgColor = 0x00000000;
		camOther.bgColor = 0x00000000;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOther, false);

		FlxG.cameras.setDefaultDrawTarget(camGame, true);
		CustomFadeTransition.nextCamera = camOther;

		camFollow = new FlxPoint();
		camFollowPos = new FlxObject(0, 0, 1, 1);
		add(camFollowPos);

		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);

		// Loading the Song
		if (SONG == null) SONG = Song.loadFromJson('tutorial');
		var songName:String = Paths.formatToSongPath(SONG.song);
		Conductor.mapBPMChanges(SONG);
		Conductor.changeBPM(SONG.bpm);

		storyDifficultyText = CoolUtil.difficulties[storyDifficulty];

		// String that contains the mode defined here so it isn't necessary to call changePresence for each mode
		if (isStoryMode) detailsText = "Story Mode: " + WeekData.getCurrentWeek().weekName; 
		else detailsText = "Freeplay";

		detailsPausedText = "Paused - " + detailsText; // String for when the game is paused

		changeDiscordPresence("Loading", false, true);

		curStage = SONG.stage;
		if (curStage == null || curStage.length < 1) {
			switch(songName) {
				case 'spookeez' | 'south' | 'monster':
					curStage = 'spooky';
				case 'pico' | 'blammed' | 'philly' | 'philly-nice':
					curStage = 'philly';
				case 'milf' | 'satin-panties' | 'high':
					curStage = 'limo';
				case 'cocoa' | 'eggnog':
					curStage = 'mall';
				case 'winter-horrorland':
					curStage = 'mallEvil';
				case 'senpai' | 'roses':
					curStage = 'school';
				case 'thorns':
					curStage = 'schoolEvil';
				case 'ugh' | 'guns' | 'stress':
					curStage = 'tank';
				default:
					curStage = 'stage';
			}
			SONG.stage = curStage;
		}

		var gfVersion:String = SONG.gfVersion;
		if (gfVersion == null || gfVersion.length < 1) {
			switch(curStage) {
				case 'limo':
					gfVersion = 'gf-car';
				case 'mall' | 'mallEvil':
					gfVersion = 'gf-christmas';
				case 'school' | 'schoolEvil':
					gfVersion = 'gf-pixel';
				case 'tank':
					gfVersion = 'gf-tankmen';
				default:
					gfVersion = 'gf';
			}

			switch(songName) {
				case 'stress':
					gfVersion = 'pico-speaker';
			}

			SONG.gfVersion = gfVersion;
		}

		var stageData:StageFile = StageData.getStageFile(curStage);
		if (stageData == null) { // Default Stage
			stageData = {
				directory: "",
				defaultZoom: 0.9,
				isPixelStage: false,

				boyfriend: [770, 100],
				girlfriend: [400, 130],
				opponent: [100, 100],
				hide_girlfriend: false,

				camera_boyfriend: [0, 0],
				camera_opponent: [0, 0],
				camera_girlfriend: [0, 0],
				camera_speed: 1
			};
		}

		defaultCamZoom = stageData.defaultZoom;
		isPixelStage = stageData.isPixelStage;
		BF_X = stageData.boyfriend[0];
		BF_Y = stageData.boyfriend[1];
		GF_X = stageData.girlfriend[0];
		GF_Y = stageData.girlfriend[1];
		DAD_X = stageData.opponent[0];
		DAD_Y = stageData.opponent[1];

		// just incase if anyone wondering why is it here, well it was because its here in vanilla psych
		grpNoteSplashes = new FlxTypedGroup<NoteSplash>();

		if (stageData.camera_speed != null) cameraSpeed = stageData.camera_speed;
		if (isPixelStage) introSoundsSuffix = '-pixel';

		boyfriendCameraOffset = stageData.camera_boyfriend;
		if (boyfriendCameraOffset == null)
			boyfriendCameraOffset = [0, 0];

		opponentCameraOffset = stageData.camera_opponent;
		if (opponentCameraOffset == null)
			opponentCameraOffset = [0, 0];

		girlfriendCameraOffset = stageData.camera_girlfriend;
		if (girlfriendCameraOffset == null)
			girlfriendCameraOffset = [0, 0];

		// Characters
		boyfriendGroup = new FlxSpriteGroup(BF_X, BF_Y);
		dadGroup = new FlxSpriteGroup(DAD_X, DAD_Y);
		gfGroup = new FlxSpriteGroup(GF_X, GF_Y);

		makeStage();

		add(gfGroup);
		add(dadGroup);
		add(boyfriendGroup);

		makeForeStage();

		#if LUA_ALLOWED
		luaDebugGroup = new FlxTypedGroup<DebugLuaText>();
		luaDebugGroup.cameras = [camOther];
		add(luaDebugGroup);

		// "GLOBAL" SCRIPTS
		executeLuas('scripts');

		// STAGE SCRIPTS
		executeLua('stages/' + curStage + '.lua');
		#end

		if (!stageData.hide_girlfriend) {
			gf = new Character(0, 0, gfVersion);
			gf.scrollFactor.set(0.95, 0.95);
			startCharacterPos(gf);
			gfGroup.add(gf);

			startCharacterLua(gf.curCharacter);

			if (gfVersion == 'pico-speaker' && !ClientPrefs.lowQuality) {
				var firstTank:TankmenBG = new TankmenBG(20, 500, true);
				firstTank.resetShit(20, 600, true);
				firstTank.strumTime = 10;
				tankmanRun.add(firstTank);

				for (i in 0...TankmenBG.animationNotes.length) {
					if (FlxG.random.bool(16)) {
						var tankBih = tankmanRun.recycle(TankmenBG);
						tankBih.strumTime = TankmenBG.animationNotes[i][0];
						tankBih.resetShit(500, 200 + FlxG.random.int(50, 100), TankmenBG.animationNotes[i][1] < 2);
						tankmanRun.add(tankBih);
					}
				}
			}
		}

		dad = new Character(0, 0, SONG.player2);
		startCharacterPos(dad, true);
		dadGroup.add(dad);

		startCharacterLua(dad.curCharacter);

		boyfriend = new Boyfriend(0, 0, SONG.player1);
		startCharacterPos(boyfriend);
		boyfriendGroup.add(boyfriend);

		startCharacterLua(boyfriend.curCharacter);

		// Cam Position
		var camPos:FlxPoint = new FlxPoint(girlfriendCameraOffset[0], girlfriendCameraOffset[1]);
		if (gf != null) {
			camPos.x += gf.getGraphicMidpoint().x + gf.cameraPosition[0];
			camPos.y += gf.getGraphicMidpoint().y + gf.cameraPosition[1];
		}
		else {
			camPos.x += FlxMath.lerp(
				dad.getGraphicMidpoint().x + dad.cameraPosition[0],
				boyfriend.getGraphicMidpoint().x + boyfriend.cameraPosition[0],
				0.5
			);
			camPos.y += FlxMath.lerp(
				dad.getGraphicMidpoint().y + dad.cameraPosition[1],
				boyfriend.getGraphicMidpoint().y + boyfriend.cameraPosition[1],
				0.5
			);
		}

		snapCamFollowToPos(camPos.x, camPos.y);
		if (prevCamFollow != null) {
			camFollow = prevCamFollow;
			prevCamFollow = null;
		}
		if (prevCamFollowPos != null) {
			camFollowPos = prevCamFollowPos;
			prevCamFollowPos = null;
		}

		if (dad.curCharacter.startsWith('gf')) {
			dad.setPosition(GF_X, GF_Y);
			if (gf != null) gf.visible = false;
		}

		camGame.follow(camFollowPos, LOCKON, 1);
		camGame.focusOn(camFollow);
		camGame.zoom = defaultCamZoom;

		makeStagePost();

		// Dialogues
		var file:String = Paths.json(songName + '/dialogue'); //Checks for json/Psych Engine dialogue
		if (OpenFlAssets.exists(file)) dialogueJson = DialogueBoxPsych.parseDialogue(file);

		var file:String = Paths.txt(songName + '/' + songName + 'Dialogue'); //Checks for vanilla/Senpai dialogue
		if (OpenFlAssets.exists(file)) dialogue = CoolUtil.coolTextFile(file);

		makeHUD();

		generateSong(SONG.song);
		moveCameraSection();
		startingSong = true;

		// if (SONG.song == 'South')
		// FlxG.camera.alpha = 0.7;
		// UI_camera.zoom = 1;

		// cameras = [FlxG.cameras.list[1]];

		// CUSTOM NOTETYPES/EVENTS LUA
		#if LUA_ALLOWED
		for (notetype in noteTypeMap.keys())
			executeLua('custom_notetypes/' + notetype + '.lua');

		for (event in eventPushedMap.keys())
			executeLua('custom_events/' + event + '.lua');
		#end
		noteTypeMap.clear();
		noteTypeMap = null;
		eventPushedMap.clear();
		eventPushedMap = null;

		startSpecificSong(songName);
		#if LUA_ALLOWED // SONG SPECIFIC SCRIPTS
		executeLuas('data/$songName');
		#end

		// PRECACHING!!
		if(ClientPrefs.hitsoundVolume > 0) precacheList.set('hitsound', 'sound');
		precacheList.set('missnote1', 'sound');
		precacheList.set('missnote2', 'sound');
		precacheList.set('missnote3', 'sound');

		if (PauseSubState.songName != null)
			precacheList.set(PauseSubState.songName, 'music');
		else if(ClientPrefs.pauseMusic != 'None')
			precacheList.set(Paths.formatToSongPath(ClientPrefs.pauseMusic), 'music');

		precacheList.set('alphabet', 'image');

		cacheCountdown();
		cachePopUpScore();
		GameOverSubstate.cache();
		for (key => type in precacheList) {
			switch(type) {
				case 'image':
					Paths.image(key);
				case 'sound':
					Paths.sound(key);
				case 'music':
					Paths.music(key);
			}
		}

		Paths.clearUnusedMemory();
		Paths.compress(6);

		changeDiscordPresence("Starting");
		startSpecificSongPost(songName);
		RecalculateRating();

		Conductor.safeZoneOffset = (ClientPrefs.safeFrames / 60) * 1000;
		if (ClientPrefs.controllerMode) initializeGamepads();
		initializeKeyboard();

		callOnLuas('onCreatePost');
		cleanupLuas();
		super.create();

		CustomFadeTransition.nextCamera = camOther;
	}

	function startSpecificSong(songName:String) {
		switch(songName) {
			case 'stress': {
				GameOverSubstate.characterName = 'bf-holding-gf-dead';
			}
			case 'tutorial': {
				canTweenCamZoom = true;
				dontZoomCam = true;

				canTweenCamZoomBoyfriend = 1;
				canTweenCamZoomDad = 1.3;
				canTweenCamZoomGf = 1.3;

				moveCameraSection();
			}
			case 'south': if (isStoryMode) {
				lightShutOffEnd = true;
				lightShutOffColor = FlxColor.BLACK;
			}
			case 'eggnog': if (isStoryMode) {
				lightShutOffEnd = true;
				lightShutOffColor = FlxColor.BLACK;
			}
		}

		if (isStoryMode && !seenCutscene) {
			switch(songName) {
				case 'monster': {
					lightShutOffStart = true;
					lightShutOffColor = FlxColor.WHITE;
					lightShutOffStartDelay = .1;
					lightShutOffStartDuration = 1;
					lightShutOffStartComplete = function() {
						FlxG.sound.play(Paths.soundRandom('thunder_', 1, 2), .4);

						generateStaticArrows(0, true);
						generateStaticArrows(1, true);
						camHUD.visible = true;
						camHUD.alpha = 0;

						FlxTween.tween(camHUD, {alpha: 1}, 2, {
							onComplete: function(_) {
								startCountdown();
							}
						});
					};
				}
				case 'winter-horrorland': {
					lightShutOffStart = true;
					lightShutOffColor = FlxColor.BLACK;
					lightShutOffStartDelay = .03;
					lightShutOffStartDuration = .3;
					lightShutOffStartComplete = function() {
						generateStaticArrows(0, true);
						generateStaticArrows(1, true);
						camHUD.visible = true;
						camHUD.alpha = 0;

						FlxTween.tween(camHUD, {alpha: 1}, 2);
						new FlxTimer().start(.5, function(_) {
							FlxTween.tween(camGame, {zoom: defaultCamZoom}, 2.5, {
								ease: FlxEase.quadInOut,
								onComplete: function(_) {
									startCountdown();
									if (curSection < 0) moveCamera(false);
									else moveCameraSection();
								}
							});
						});
					};
				}
			}
		}
	}

	function startSpecificSongPost(songName:String) {
		var screenCover:FlxSprite = null;
		if (lightShutOffStart) {
			screenCover = new FlxSprite().makeGraphic(1, 1, lightShutOffColor);
			screenCover.setGraphicSize(16384);
			screenCover.scrollFactor.set();
			screenCover.updateHitbox();
			screenCover.screenCenter();
			add(screenCover);

			FlxTween.tween(screenCover, {alpha: 0}, lightShutOffStartDuration, {
				startDelay: lightShutOffStartDelay,
				onComplete: function(_) {
					if (lightShutOffStartComplete != null)
						lightShutOffStartComplete();

					remove(screenCover);
					screenCover.kill();
					screenCover.destroy();
				}
			});
		}

		var doof:DialogueBox = new DialogueBox(false, dialogue); // Vanilla/Senpai Dialogue
		doof.scrollFactor.set();
		doof.finishThing = startCountdown;
		doof.nextDialogueThing = startNextDialogue;
		doof.skipDialogueThing = skipDialogue;
		doof.camera = camHUD;

		if (isStoryMode && !seenCutscene) {
			switch(songName) {
				case 'monster': {
					if (screenCover != null) screenCover.blend = ADD;
					camHUD.visible = false;
					inCutscene = true;

					FlxG.sound.play(Paths.soundRandom('thunder_', 1, 2));

					if (gf != null) gf.playAnim('scared', true);
					boyfriend.playAnim('scared', true);

					moveCamera(true);
					snapCamFollowToPos(camFollow.x, camFollow.y);
					camGame.focusOn(camFollow);
				}
				case 'winter-horrorland': {
					camHUD.visible = false;
					inCutscene = true;

					FlxG.sound.play(Paths.sound('Lights_Turn_On'));

					snapCamFollowToPos(400, -2050);
					camGame.focusOn(camFollow);
					camGame.zoom = 1.5;
				}
				case 'senpai' | 'roses' | 'thorns': {
					if(songName == 'roses') FlxG.sound.play(Paths.sound('ANGRY'));
					schoolIntro(doof);
				}
				case 'ugh' | 'guns' | 'stress': {
					tankIntro();
				}
				default:
					startCountdown();
			}
		}
		else
			startCountdown();

		seenCutscene = true;
	}

	function makeHUD() {
		var showTime:Bool = (ClientPrefs.timeBarType != 'Disabled');
		updateTime = showTime;

		timeTxt = new FlxText(STRUM_X + (FlxG.width / 2) - 248, 19, 400, "", 32);
		timeTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timeTxt.scrollFactor.set();
		timeTxt.visible = showTime;
		timeTxt.borderSize = 2;
		timeTxt.alpha = 0;
		timeTxt.antialiasing = ClientPrefs.globalAntialiasing;
		if (ClientPrefs.downScroll) timeTxt.y = FlxG.height - 44;
		if (ClientPrefs.timeBarType == 'Song Name') {
			timeTxt.text = SONG.song;
			timeTxt.size = 24;
			timeTxt.y += 3;
		}

		timeBarBG = new AttachedSprite('timeBar');
		timeBarBG.setPosition(timeTxt.x, timeTxt.y + (timeTxt.height / 4));
		timeBarBG.scrollFactor.set();
		timeBarBG.color = FlxColor.BLACK;
		timeBarBG.visible = showTime;
		timeBarBG.alpha = 0;
		timeBarBG.xAdd = -4;
		timeBarBG.yAdd = -4;
		timeBarBG.antialiasing = ClientPrefs.globalAntialiasing;

		timeBar = new FlxBar(
			timeBarBG.x + 4, timeBarBG.y + 4, LEFT_TO_RIGHT, Std.int(timeBarBG.width - 8), Std.int(timeBarBG.height - 8),
			this, 'songPercent', 0, 1
		);
		timeBar.createFilledBar(0xFF000000, 0xFFFFFFFF);
		timeBar.scrollFactor.set();
		timeBar.numDivisions = 800; //How much lag this causes?? Should i tone it down to idk, 400 or 200?
		timeBar.alpha = 0;
		timeBar.visible = showTime;
		timeBar.antialiasing = ClientPrefs.globalAntialiasing;

		timeBarBG.sprTracker = timeBar;

		healthBarBG = new AttachedSprite('healthBar');
		healthBarBG.scrollFactor.set();
		healthBarBG.screenCenter(X);
		healthBarBG.y = FlxG.height * 0.89;
		healthBarBG.visible = !ClientPrefs.hideHud;
		healthBarBG.xAdd = -4;
		healthBarBG.yAdd = -4;
		healthBarBG.antialiasing = ClientPrefs.globalAntialiasing;
		if (ClientPrefs.downScroll) healthBarBG.y = 0.11 * FlxG.height;

		healthBar = new FlxBar(healthBarBG.x + 4, healthBarBG.y + 4, RIGHT_TO_LEFT, Std.int(healthBarBG.width - 8), Std.int(healthBarBG.height - 8), this,
			'health', 0, 2);
		healthBar.scrollFactor.set();
		// healthBar
		healthBar.visible = !ClientPrefs.hideHud;
		healthBar.alpha = ClientPrefs.healthBarAlpha;
		healthBar.antialiasing = ClientPrefs.globalAntialiasing;
		healthBarBG.sprTracker = healthBar;

		scoreTxt = new FlxText(0, healthBarBG.y + 36, FlxG.width, "", 20);
		scoreTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.scrollFactor.set();
		scoreTxt.borderSize = 1.25;
		scoreTxt.visible = !ClientPrefs.hideHud;
		scoreTxt.antialiasing = ClientPrefs.globalAntialiasing;

		botplayTxt = new FlxText(400, timeBarBG.y + 55, FlxG.width - 800, "BOTPLAY", 32);
		botplayTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		botplayTxt.scrollFactor.set();
		botplayTxt.borderSize = 1.25;
		botplayTxt.visible = cpuControlled;
		botplayTxt.antialiasing = ClientPrefs.globalAntialiasing;
		if (ClientPrefs.downScroll) botplayTxt.y = timeBarBG.y - 78;

		iconP1 = new HealthIcon(boyfriend.healthIcon, true);
		iconP1.y = healthBar.y - 75;
		iconP1.visible = !ClientPrefs.hideHud;
		iconP1.alpha = ClientPrefs.healthBarAlpha;

		iconP2 = new HealthIcon(dad.healthIcon, false);
		iconP2.y = healthBar.y - 75;
		iconP2.visible = !ClientPrefs.hideHud;
		iconP2.alpha = ClientPrefs.healthBarAlpha;

		reloadHealthBarColors();

		// Strumlines
		strumLine = new FlxSprite(ClientPrefs.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X, 50).makeGraphic(FlxG.width, 10);
		if(ClientPrefs.downScroll) strumLine.y = FlxG.height - 150;

		var splash:NoteSplash = new NoteSplash(100, 100, 0); // Precaching
		grpNoteSplashes.add(splash);
		splash.alpha = 0.0;

		strumLineNotes = new FlxTypedGroup<StrumNote>();
		opponentStrums = new FlxTypedGroup<StrumNote>();
		playerStrums = new FlxTypedGroup<StrumNote>();

		// Layering
		timeBarBG.camera = camHUD; add(timeBarBG);
		timeBar.camera = camHUD; add(timeBar);
		timeTxt.camera = camHUD; add(timeTxt);

		strumLineNotes.camera = camHUD; add(strumLineNotes);
		grpNoteSplashes.camera = camHUD; add(grpNoteSplashes);

		healthBarBG.camera = camHUD; add(healthBarBG);
		healthBar.camera = camHUD; add(healthBar);

		iconP1.camera = camHUD; add(iconP1);
		iconP2.camera = camHUD; add(iconP2);

		scoreTxt.camera = camHUD; add(scoreTxt);
		botplayTxt.camera = camHUD; add(botplayTxt);
	}

	function makeStagePost() {
		switch(curStage) {
			case 'stage': {
				if(!ClientPrefs.lowQuality) {
					var stageLight:BGSprite = new BGSprite('stage_light', -125, -100, 0.9, 0.9);
					stageLight.setGraphicSize(Std.int(stageLight.width * 1.1));
					stageLight.updateHitbox();
					add(stageLight);

					var stageLight:BGSprite = new BGSprite('stage_light', 1225, -100, 0.9, 0.9);
					stageLight.setGraphicSize(Std.int(stageLight.width * 1.1));
					stageLight.updateHitbox();
					stageLight.flipX = true;
					add(stageLight);

					var stageCurtains:BGSprite = new BGSprite('stagecurtains', -500, -300, 1.3, 1.3);
					stageCurtains.setGraphicSize(Std.int(stageCurtains.width * 0.9));
					stageCurtains.updateHitbox();
					add(stageCurtains);
				}
			}

			case 'limo': {
				resetFastCar();
				addBehindGF(fastCar);
			}

			case 'schoolEvil': {
				var evilTrail = new FlxTrail(dad, null, 4, 24, 0.3, 0.069); //nice
				addBehindDad(evilTrail);
			}
		}
	}

	function makeStage() {
		switch(curStage) {
			case 'stage': { //Week 1
				var bg:BGSprite = new BGSprite('stageback', -600, -200, 0.9, 0.9);
				add(bg);

				var stageFront:BGSprite = new BGSprite('stagefront', -650, 600, 0.9, 0.9);
				stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
				stageFront.updateHitbox();
				add(stageFront);

				dadbattleSmokes = new FlxSpriteGroup(); //troll'd
			}

			case 'spooky': { //Week 2
				if (!ClientPrefs.lowQuality)
					halloweenBG = new BGSprite('halloween_bg', -200, -100, ['halloweem bg0', 'halloweem bg lightning strike']);
				else
					halloweenBG = new BGSprite('halloween_bg_low', -200, -100);

				add(halloweenBG);

				halloweenWhite = new BGSprite(null, -800, -400, 0, 0);
				halloweenWhite.makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.WHITE);
				halloweenWhite.alpha = 0;
				halloweenWhite.blend = ADD;

				//PRECACHE SOUND
				precacheList.set('thunder_1', 'sound');
				precacheList.set('thunder_2', 'sound');
			}

			case 'philly': { //Week 3
				phillyLightsColors = [0xFF31A2FD, 0xFF31FD8C, 0xFFFB33F5, 0xFFFD4531, 0xFFFBA633];

				if (!ClientPrefs.lowQuality) {
					var bg:BGSprite = new BGSprite('philly/sky', -100, 0, 0.1, 0.1);
					add(bg);
				}

				var city:BGSprite = new BGSprite('philly/city', -10, 0, 0.3, 0.3);
				city.setGraphicSize(Std.int(city.width * 0.85));
				city.updateHitbox();
				add(city);

				phillyWindow = new BGSprite('philly/window', city.x, city.y, 0.3, 0.3);
				phillyWindow.setGraphicSize(Std.int(phillyWindow.width * 0.85));
				phillyWindow.updateHitbox();
				phillyWindow.alpha = 0;
				add(phillyWindow);

				if(!ClientPrefs.lowQuality) {
					var streetBehind:BGSprite = new BGSprite('philly/behindTrain', -40, 50);
					add(streetBehind);
				}

				phillyTrain = new BGSprite('philly/train', 2000, 360);
				add(phillyTrain);

				phillyStreet = new BGSprite('philly/street', -40, 50);
				add(phillyStreet);

				trainSound = new FlxSound().loadEmbedded(Paths.sound('train_passes'));
				FlxG.sound.list.add(trainSound);
			}

			case 'limo': { //Week 4
				var skyBG:BGSprite = new BGSprite('limo/limoSunset', -120, -50, 0.1, 0.1);
				add(skyBG);

				if (!ClientPrefs.lowQuality) {
					limoMetalPole = new BGSprite('gore/metalPole', -500, 220, 0.4, 0.4);
					add(limoMetalPole);

					bgLimo = new BGSprite('limo/bgLimo', -150, 480, 0.4, 0.4, ['background limo pink'], true);
					add(bgLimo);

					limoCorpse = new BGSprite('gore/noooooo', -500, limoMetalPole.y - 130, 0.4, 0.4, ['Henchmen on rail'], true);
					add(limoCorpse);

					limoCorpseTwo = new BGSprite('gore/noooooo', -500, limoMetalPole.y, 0.4, 0.4, ['henchmen death'], true);
					add(limoCorpseTwo);

					grpLimoDancers = new FlxTypedGroup<BackgroundDancer>();
					add(grpLimoDancers);

					for (i in 0...5) {
						var dancer:BackgroundDancer = new BackgroundDancer((370 * i) + 170, bgLimo.y - 400);
						dancer.scrollFactor.set(0.4, 0.4);
						grpLimoDancers.add(dancer);
					}

					limoLight = new BGSprite('gore/coldHeartKiller', limoMetalPole.x - 180, limoMetalPole.y - 80, 0.4, 0.4);
					add(limoLight);

					grpLimoParticles = new FlxTypedGroup<BGSprite>();
					add(grpLimoParticles);

					//PRECACHE BLOOD
					var particle:BGSprite = new BGSprite('gore/stupidBlood', -400, -400, 0.4, 0.4, ['blood'], false);
					particle.alpha = 0.01;
					grpLimoParticles.add(particle);
					resetLimoKill();

					//PRECACHE SOUND
					precacheList.set('dancerdeath', 'sound');
				}

				limo = new BGSprite('limo/limoDrive', -120, 550, 1, 1, ['Limo stage'], true);

				fastCar = new BGSprite('limo/fastCarLol', -300, 160);
				fastCar.active = true;
				limoKillingState = 0;
			}

			case 'mall': { //Week 5 - Cocoa, Eggnog
				var bg:BGSprite = new BGSprite('christmas/bgWalls', -1000, -500, 0.2, 0.2);
				bg.setGraphicSize(Std.int(bg.width * 0.8));
				bg.updateHitbox();
				add(bg);

				if (!ClientPrefs.lowQuality) {
					upperBoppers = new BGSprite('christmas/upperBop', -240, -90, 0.33, 0.33, ['Upper Crowd Bob']);
					upperBoppers.setGraphicSize(Std.int(upperBoppers.width * 0.85));
					upperBoppers.updateHitbox();
					add(upperBoppers);

					var bgEscalator:BGSprite = new BGSprite('christmas/bgEscalator', -1100, -600, 0.3, 0.3);
					bgEscalator.setGraphicSize(Std.int(bgEscalator.width * 0.9));
					bgEscalator.updateHitbox();
					add(bgEscalator);
				}

				var tree:BGSprite = new BGSprite('christmas/christmasTree', 370, -250, 0.40, 0.40);
				add(tree);

				bottomBoppers = new BGSprite('christmas/bottomBop', -300, 140, 0.9, 0.9, ['Bottom Level Boppers Idle']);
				bottomBoppers.animation.addByPrefix('hey', 'Bottom Level Boppers HEY', 24, false);
				bottomBoppers.setGraphicSize(Std.int(bottomBoppers.width * 1));
				bottomBoppers.updateHitbox();
				add(bottomBoppers);

				var fgSnow:BGSprite = new BGSprite('christmas/fgSnow', -600, 700);
				add(fgSnow);

				santa = new BGSprite('christmas/santa', -840, 150, 1, 1, ['santa idle in fear']);
				add(santa);

				//PRECACHE SOUND
				precacheList.set('Lights_Shut_off', 'sound');
			}

			case 'mallEvil': { //Week 5 - Winter Horrorland
				var bg:BGSprite = new BGSprite('christmas/evilBG', -400, -500, 0.2, 0.2);
				bg.setGraphicSize(Std.int(bg.width * 0.8));
				bg.updateHitbox();
				add(bg);

				var evilTree:BGSprite = new BGSprite('christmas/evilTree', 300, -300, 0.2, 0.2);
				add(evilTree);

				var evilSnow:BGSprite = new BGSprite('christmas/evilSnow', -200, 700);
				add(evilSnow);
			}

			case 'school': { //Week 6 - Senpai, Roses
				GameOverSubstate.deathSoundName = 'fnf_loss_sfx-pixel';
				GameOverSubstate.loopSoundName = 'gameOver-pixel';
				GameOverSubstate.endSoundName = 'gameOverEnd-pixel';
				GameOverSubstate.characterName = 'bf-pixel-dead';

				var repositionShit = -200;

				var bgSky:BGSprite = new BGSprite('weeb/weebSky', 0, 0, 0.1, 0.1);
				bgSky.antialiasing = false;
				add(bgSky);

				var bgSchool:BGSprite = new BGSprite('weeb/weebSchool', repositionShit, 0, 0.6, 0.90);
				bgSchool.antialiasing = false;
				add(bgSchool);

				var bgStreet:BGSprite = new BGSprite('weeb/weebStreet', repositionShit, 0, 0.95, 0.95);
				bgStreet.antialiasing = false;
				add(bgStreet);

				var widShit = Std.int(bgSky.width * 6);
				if (!ClientPrefs.lowQuality) {
					var fgTrees:BGSprite = new BGSprite('weeb/weebTreesBack', repositionShit + 170, 130, 0.9, 0.9);
					fgTrees.setGraphicSize(Std.int(widShit * 0.8));
					fgTrees.updateHitbox();
					fgTrees.antialiasing = false;
					add(fgTrees);
				}

				var bgTrees:FlxSprite = new FlxSprite(repositionShit - 380, -800);
				bgTrees.frames = Paths.getPackerAtlas('weeb/weebTrees');
				bgTrees.animation.add('treeLoop', [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18], 12);
				bgTrees.animation.play('treeLoop');
				bgTrees.scrollFactor.set(0.85, 0.85);
				bgTrees.antialiasing = false;
				add(bgTrees);

				if (!ClientPrefs.lowQuality) {
					var treeLeaves:BGSprite = new BGSprite('weeb/petals', repositionShit, -40, 0.85, 0.85, ['PETALS ALL'], true);
					treeLeaves.setGraphicSize(widShit);
					treeLeaves.updateHitbox();
					treeLeaves.antialiasing = false;
					add(treeLeaves);
				}

				bgSky.setGraphicSize(widShit);
				bgSchool.setGraphicSize(widShit);
				bgStreet.setGraphicSize(widShit);
				bgTrees.setGraphicSize(Std.int(widShit * 1.4));

				bgSky.updateHitbox();
				bgSchool.updateHitbox();
				bgStreet.updateHitbox();
				bgTrees.updateHitbox();

				if(!ClientPrefs.lowQuality) {
					bgGirls = new BackgroundGirls(-100, 190);
					bgGirls.scrollFactor.set(0.9, 0.9);

					bgGirls.setGraphicSize(Std.int(bgGirls.width * daPixelZoom));
					bgGirls.updateHitbox();
					add(bgGirls);
				}
			}

			case 'schoolEvil': { //Week 6 - Thorns
				GameOverSubstate.deathSoundName = 'fnf_loss_sfx-pixel';
				GameOverSubstate.loopSoundName = 'gameOver-pixel';
				GameOverSubstate.endSoundName = 'gameOverEnd-pixel';
				GameOverSubstate.characterName = 'bf-pixel-dead';

				var posX = 400;
				var posY = 200;

				/*if (!ClientPrefs.lowQuality) { //Does this even do something?
					var waveEffectBG = new FlxWaveEffect(FlxWaveMode.ALL, 2, -1, 3, 2);
					var waveEffectFG = new FlxWaveEffect(FlxWaveMode.ALL, 2, -1, 5, 2);
				}*/

				if (!ClientPrefs.lowQuality) {
					var bg:BGSprite = new BGSprite('weeb/animatedEvilSchool', posX, posY, 0.8, 0.9, ['background 2'], true);
					bg.scale.set(6, 6);
					bg.antialiasing = false;
					add(bg);

					bgGhouls = new BGSprite('weeb/bgGhouls', -100, 190, 0.9, 0.9, ['BG freaks glitch instance'], false);
					bgGhouls.setGraphicSize(Std.int(bgGhouls.width * daPixelZoom));
					bgGhouls.updateHitbox();
					bgGhouls.visible = false;
					bgGhouls.antialiasing = false;
					add(bgGhouls);
				}
				else {
					var bg:BGSprite = new BGSprite('weeb/animatedEvilSchool_low', posX, posY, 0.8, 0.9);
					bg.scale.set(6, 6);
					bg.antialiasing = false;
					add(bg);
				}
			}

			case 'tank': { //Week 7
				var sky:BGSprite = new BGSprite('tankSky', -400, -400, 0, 0);
				add(sky);

				if (!ClientPrefs.lowQuality) {
					var clouds:BGSprite = new BGSprite('tankClouds', FlxG.random.int(-700, -100), FlxG.random.int(-20, 20), 0.1, 0.1);
					clouds.active = true;
					clouds.velocity.x = FlxG.random.float(5, 15);
					add(clouds);

					var mountains:BGSprite = new BGSprite('tankMountains', -300, -20, 0.2, 0.2);
					mountains.setGraphicSize(Std.int(1.2 * mountains.width));
					mountains.updateHitbox();
					add(mountains);

					var buildings:BGSprite = new BGSprite('tankBuildings', -200, 0, 0.3, 0.3);
					buildings.setGraphicSize(Std.int(1.1 * buildings.width));
					buildings.updateHitbox();
					add(buildings);
				}

				var ruins:BGSprite = new BGSprite('tankRuins',-200,0,.35,.35);
				ruins.setGraphicSize(Std.int(1.1 * ruins.width));
				ruins.updateHitbox();
				add(ruins);

				if (!ClientPrefs.lowQuality) {
					var smokeLeft:BGSprite = new BGSprite('smokeLeft', -200, -100, 0.4, 0.4, ['SmokeBlurLeft'], true);
					add(smokeLeft);

					var smokeRight:BGSprite = new BGSprite('smokeRight', 1100, -100, 0.4, 0.4, ['SmokeRight'], true);
					add(smokeRight);

					tankWatchtower = new BGSprite('tankWatchtower', 100, 50, 0.5, 0.5, ['watchtower gradient color']);
					add(tankWatchtower);
				}

				tankGround = new BGSprite('tankRolling', 300, 300, 0.5, 0.5,['BG tank w lighting'], true);
				add(tankGround);

				tankmanRun = new FlxTypedGroup<TankmenBG>();
				add(tankmanRun);

				var ground:BGSprite = new BGSprite('tankGround', -420, -150);
				ground.setGraphicSize(Std.int(1.15 * ground.width));
				ground.updateHitbox();
				add(ground);

				moveTank();

				foregroundSprites = new FlxTypedGroup<BGSprite>();
				foregroundSprites.add(new BGSprite('tank0', -500, 650, 1.7, 1.5, ['fg']));
				if(!ClientPrefs.lowQuality) foregroundSprites.add(new BGSprite('tank1', -300, 750, 2, 0.2, ['fg']));
				foregroundSprites.add(new BGSprite('tank2', 450, 940, 1.5, 1.5, ['foreground']));
				if(!ClientPrefs.lowQuality) foregroundSprites.add(new BGSprite('tank4', 1300, 900, 1.5, 1.5, ['fg']));
				foregroundSprites.add(new BGSprite('tank5', 1620, 700, 1.5, 1.5, ['fg']));
				if(!ClientPrefs.lowQuality) foregroundSprites.add(new BGSprite('tank3', 1300, 1200, 3.5, 2.5, ['fg']));
			}
		}
	}

	function makeForeStage() {
		switch(curStage) {
			case 'spooky': {
				add(halloweenWhite);
			}

			case 'limo': {
				insert(members.indexOf(gfGroup) + 1, limo);
			}

			case 'tank': {
				add(foregroundSprites);
			}
		}
	}

	function updateStage(elapsed:Float) {
		switch(curStage) {
			case 'tank': {
				moveTank(elapsed);
			}
			case 'schoolEvil': {
				if (bgGhouls != null && bgGhouls.animation.curAnim.finished)
					bgGhouls.visible = false;
			}
			case 'mall': {
				if (heyTimer > 0) {
					heyTimer -= elapsed;
					if (heyTimer <= 0) {
						bottomBoppers.dance(true);
						heyTimer = 0;
					}
				}
			}
			case 'philly': {
				if (trainMoving) {
					trainFrameTiming += elapsed;

					if (trainFrameTiming >= 1 / 24) {
						updateTrainPos();
						trainFrameTiming = 0;
					}
				}

				phillyWindow.alpha -= (Conductor.crochet / 1000) * elapsed * 1.5;
				if (phillyGlowParticles != null) {
					var i:Int = phillyGlowParticles.members.length;
					while (--i >= 0) {
						var particle = phillyGlowParticles.members[i];
						if (particle.alpha < 0) {
							particle.kill();
							phillyGlowParticles.remove(particle, true);
							particle.destroy();
						}
					}
				}
			}
			case 'limo': {
				if (!ClientPrefs.lowQuality) {
					grpLimoParticles.forEach(function(spr:BGSprite) {
						if(spr.animation.curAnim.finished) {
							spr.kill();
							grpLimoParticles.remove(spr, true);
							spr.destroy();
						}
					});

					switch(limoKillingState) {
						case 1:
							limoMetalPole.x += 5000 * elapsed;
							limoLight.x = limoMetalPole.x - 180;
							limoCorpse.x = limoLight.x - 50;
							limoCorpseTwo.x = limoLight.x + 35;

							var dancers:Array<BackgroundDancer> = grpLimoDancers.members;
							for (i in 0...dancers.length) {
								if(dancers[i].x < FlxG.width * 1.5 && limoLight.x > (370 * i) + 170) {
									switch(i) {
										case 0 | 3:
											if(i == 0) FlxG.sound.play(Paths.sound('dancerdeath'), 0.5);

											var diffStr:String = i == 3 ? ' 2 ' : ' ';
											var particle:BGSprite = new BGSprite('gore/noooooo', dancers[i].x + 200, dancers[i].y, 0.4, 0.4, ['hench leg spin' + diffStr + 'PINK'], false);
											grpLimoParticles.add(particle);
											var particle:BGSprite = new BGSprite('gore/noooooo', dancers[i].x + 160, dancers[i].y + 200, 0.4, 0.4, ['hench arm spin' + diffStr + 'PINK'], false);
											grpLimoParticles.add(particle);
											var particle:BGSprite = new BGSprite('gore/noooooo', dancers[i].x, dancers[i].y + 50, 0.4, 0.4, ['hench head spin' + diffStr + 'PINK'], false);
											grpLimoParticles.add(particle);

											var particle:BGSprite = new BGSprite('gore/stupidBlood', dancers[i].x - 110, dancers[i].y + 20, 0.4, 0.4, ['blood'], false);
											particle.flipX = true;
											particle.angle = -57.5;
											grpLimoParticles.add(particle);
										case 1:
											limoCorpse.visible = true;
										case 2:
											limoCorpseTwo.visible = true;
									} //Note: Nobody cares about the fifth dancer because he is mostly hidden offscreen :(
									dancers[i].x += FlxG.width * 2;
								}
							}

							if(limoMetalPole.x > FlxG.width * 2) {
								resetLimoKill();
								limoSpeed = 800;
								limoKillingState = 2;
							}

						case 2:
							limoSpeed -= 4000 * elapsed;
							bgLimo.x -= limoSpeed * elapsed;
							if(bgLimo.x > FlxG.width * 1.5) {
								limoSpeed = 3000;
								limoKillingState = 3;
							}

						case 3:
							limoSpeed -= 2000 * elapsed;
							if(limoSpeed < 1000) limoSpeed = 1000;

							bgLimo.x -= limoSpeed * elapsed;
							if(bgLimo.x < -275) {
								limoKillingState = 4;
								limoSpeed = 800;
							}

						case 4:
							bgLimo.x = FlxMath.lerp(bgLimo.x, -150, CoolUtil.boundTo(elapsed * 9, 0, 1));
							if(Math.round(bgLimo.x) == -150) {
								bgLimo.x = -150;
								limoKillingState = 0;
							}
					}

					if(limoKillingState > 2) {
						var dancers:Array<BackgroundDancer> = grpLimoDancers.members;
						for (i in 0...dancers.length) {
							dancers[i].x = (370 * i) + bgLimo.x + 280;
						}
					}
				}
			}
		}
	}

	#if (!flash && sys)
	public var runtimeShaders:Map<String, Array<String>> = new Map<String, Array<String>>();
	public function createRuntimeShader(name:String):FlxRuntimeShader {
		if (!ClientPrefs.shaders) return new FlxRuntimeShader();

		if (!runtimeShaders.exists(name) && !initLuaShader(name)) {
			FlxG.log.warn('Shader $name is missing!');
			return new FlxRuntimeShader();
		}

		var arr:Array<String> = runtimeShaders.get(name);
		return new FlxRuntimeShader(arr[0], arr[1]);
	}

	public function initLuaShader(name:String, ?glslVersion:Int = 120) {
		if (!ClientPrefs.shaders) return false;

		if (runtimeShaders.exists(name)) {
			FlxG.log.warn('Shader $name was already initialized!');
			return true;
		}

		var foldersToCheck:Array<String> = [Paths.mods('shaders/')];
		if (Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods(Paths.currentModDirectory + '/shaders/'));

		for (mod in Paths.getGlobalMods())
			foldersToCheck.insert(0, Paths.mods(mod + '/shaders/'));
		
		for (folder in foldersToCheck) {
			if(FileSystem.exists(folder)) {
				var frag:String = folder + name + '.frag';
				var vert:String = folder + name + '.vert';
				var found:Bool = false;
				if (FileSystem.exists(frag)) {
					frag = File.getContent(frag);
					found = true;
				}
				else frag = null;

				if (FileSystem.exists(vert)) {
					vert = File.getContent(vert);
					found = true;
				}
				else vert = null;

				if (found) {
					runtimeShaders.set(name, [frag, vert]);
					//trace('Found shader $name!');
					return true;
				}
			}
		}

		FlxG.log.warn('Missing shader $name .frag AND .vert files!');
		return false;
	}
	#end

	function set_songSpeed(value:Float):Float {
		if (generatedMusic) {
			var ratio = value / songSpeed; //funny word huh

			for (note in notes) note.resizeByRatio(ratio);
			for (note in unspawnNotes) note.resizeByRatio(ratio);
		}

		noteKillOffset = 350 / value;
		return songSpeed = value;
	}

	function set_playbackRate(value:Float):Float {
		if (generatedMusic) {
			if (vocals != null) vocals.pitch = value;
			FlxG.sound.music.pitch = value;
		}

		FlxAnimationController.globalSpeed = value;
		Conductor.safeZoneOffset = (ClientPrefs.safeFrames / 60) * 1000 * value;
		setOnLuas('playbackRate', value);
		return playbackRate = value;
	}

	public function addTextToDebug(text:String, color:FlxColor) {
		#if LUA_ALLOWED
		luaDebugGroup.forEachAlive(function(spr:DebugLuaText) {
			spr.y += 20;
		});

		if(luaDebugGroup.members.length > 34) {
			var blah = luaDebugGroup.members[34];
			blah.destroy();
			luaDebugGroup.remove(blah);
		}
		luaDebugGroup.insert(0, new DebugLuaText(text, luaDebugGroup, color));
		#end
	}

	public function reloadHealthBarColors() {
		healthBar.createFilledBar(FlxColor.fromRGB(dad.healthColorArray[0], dad.healthColorArray[1], dad.healthColorArray[2]),
			FlxColor.fromRGB(boyfriend.healthColorArray[0], boyfriend.healthColorArray[1], boyfriend.healthColorArray[2]));

		healthBar.updateBar();
	}

	public function addCharacterToList(newCharacter:String, type:Int) {
		switch(type) {
			case 0:
				if(!boyfriendMap.exists(newCharacter)) {
					var newBoyfriend:Boyfriend = new Boyfriend(0, 0, newCharacter);
					boyfriendMap.set(newCharacter, newBoyfriend);
					boyfriendGroup.add(newBoyfriend);
					startCharacterPos(newBoyfriend);
					newBoyfriend.alpha = 0.00001;
					startCharacterLua(newBoyfriend.curCharacter);
					HealthIcon.returnGraphic(newBoyfriend.healthIcon);
				}
			case 1:
				if(!dadMap.exists(newCharacter)) {
					var newDad:Character = new Character(0, 0, newCharacter);
					dadMap.set(newCharacter, newDad);
					dadGroup.add(newDad);
					startCharacterPos(newDad, true);
					newDad.alpha = 0.00001;
					startCharacterLua(newDad.curCharacter);
					HealthIcon.returnGraphic(newDad.healthIcon);
				}
			case 2:
				if(gf != null && !gfMap.exists(newCharacter)) {
					var newGf:Character = new Character(0, 0, newCharacter);
					newGf.scrollFactor.set(0.95, 0.95);
					gfMap.set(newCharacter, newGf);
					gfGroup.add(newGf);
					startCharacterPos(newGf);
					newGf.alpha = 0.00001;
					startCharacterLua(newGf.curCharacter);
					HealthIcon.returnGraphic(newGf.healthIcon);
				}
		}
	}

	public function startCharacterLua(name:String) {
		var path = 'characters/${name}.lua';
		if (!isLuaRunning(path)) executeLua(path);
	}

	public function getLuaObject(tag:String, text:Bool=true):FlxSprite {
		if(modchartSprites.exists(tag)) return modchartSprites.get(tag);
		if(text && modchartTexts.exists(tag)) return modchartTexts.get(tag);
		if(variables.exists(tag)) return variables.get(tag);
		return null;
	}

	function startCharacterPos(char:Character, ?gfCheck:Bool = false) {
		if (gfCheck && char.curCharacter.startsWith('gf')) { //IF DAD IS GIRLFRIEND, HE GOES TO HER POSITION
			char.setPosition(GF_X, GF_Y);
			char.scrollFactor.set(0.95, 0.95);
		}
		char.x += char.positionArray[0];
		char.y += char.positionArray[1];
	}

	public function startVideo(name:String, loop:Bool = false, haccelerated:Bool = true, pauseMusic:Bool = false)
	{
		#if VIDEOS_ALLOWED
		inCutscene = true;
		
		var filepath:String = Paths.video(name);
		#if sys
		if(!FileSystem.exists(filepath))
		#else
		if(!OpenFlAssets.exists(filepath))
		#end
		{
			FlxG.log.warn('Couldnt find video file: ' + name);
			startAndEnd();
			return;
		}

		var bg = new FlxSprite(-FlxG.width, -FlxG.height).makeGraphic(FlxG.width * 3, FlxG.height * 3, FlxColor.BLACK);
		bg.scrollFactor.set();
		bg.cameras = [camHUD];
		add(bg);

		var video:VideoHandler = new VideoHandler();
		new FlxTimer().start(0.001, function(_) {
			video.playVideo(filepath, loop, haccelerated, pauseMusic);
		});
		video.finishCallback = function()
		{
			remove(bg);
			startAndEnd();
			Paths.clearUnusedMemory();
			return;
		}
		return;
		#else
		FlxG.log.warn('Platform not supported!');
		startAndEnd();
		return;
		#end
	}

	function startAndEnd()
	{
		if(endingSong)
			endSong();
		else
			startCountdown();
	}

	var dialogueCount:Int = 0;
	public var psychDialogue:DialogueBoxPsych;
	//You don't have to add a song, just saying. You can just do "startDialogue(dialogueJson);" and it should work
	public function startDialogue(dialogueFile:DialogueFile, ?song:String = null):Void
	{
		// TO DO: Make this more flexible, maybe?
		if(psychDialogue != null) return;

		if(dialogueFile.dialogue.length > 0) {
			inCutscene = true;
			precacheList.set('dialogue', 'sound');
			precacheList.set('dialogueClose', 'sound');
			psychDialogue = new DialogueBoxPsych(dialogueFile, song);
			psychDialogue.scrollFactor.set();
			if(endingSong) {
				psychDialogue.finishThing = function() {
					psychDialogue = null;
					endSong();
				}
			} else {
				psychDialogue.finishThing = function() {
					psychDialogue = null;
					startCountdown();
				}
			}
			psychDialogue.nextDialogueThing = startNextDialogue;
			psychDialogue.skipDialogueThing = skipDialogue;
			psychDialogue.cameras = [camHUD];
			add(psychDialogue);
		} else {
			FlxG.log.warn('Your dialogue file is badly formatted!');
			if(endingSong) {
				endSong();
			} else {
				startCountdown();
			}
		}
	}

	function schoolIntro(?dialogueBox:DialogueBox):Void
	{
		inCutscene = true;
		var black:FlxSprite = new FlxSprite(-100, -100).makeGraphic(FlxG.width * 2, FlxG.height * 2, FlxColor.BLACK);
		black.scrollFactor.set();
		add(black);

		var red:FlxSprite = new FlxSprite(-100, -100).makeGraphic(FlxG.width * 2, FlxG.height * 2, 0xFFff1b31);
		red.scrollFactor.set();

		var senpaiEvil:FlxSprite = new FlxSprite();
		senpaiEvil.frames = Paths.getSparrowAtlas('weeb/senpaiCrazy');
		senpaiEvil.animation.addByPrefix('idle', 'Senpai Pre Explosion', 24, false);
		senpaiEvil.setGraphicSize(Std.int(senpaiEvil.width * 6));
		senpaiEvil.scrollFactor.set();
		senpaiEvil.updateHitbox();
		senpaiEvil.screenCenter();
		senpaiEvil.x += 300;

		var songName:String = Paths.formatToSongPath(SONG.song);
		if (songName == 'roses' || songName == 'thorns')
		{
			remove(black);

			if (songName == 'thorns')
			{
				add(red);
				camHUD.visible = false;
			}
		}

		new FlxTimer().start(0.3, function(tmr:FlxTimer)
		{
			black.alpha -= 0.15;

			if (black.alpha > 0)
			{
				tmr.reset(0.3);
			}
			else
			{
				if (dialogueBox != null)
				{
					if (songName == 'thorns')
					{
						add(senpaiEvil);
						senpaiEvil.alpha = 0;
						new FlxTimer().start(0.3, function(swagTimer:FlxTimer)
						{
							senpaiEvil.alpha += 0.15;
							if (senpaiEvil.alpha < 1)
							{
								swagTimer.reset();
							}
							else
							{
								senpaiEvil.animation.play('idle');
								FlxG.sound.play(Paths.sound('Senpai_Dies'), 1, false, null, true, function()
								{
									remove(senpaiEvil);
									remove(red);
									FlxG.camera.fade(FlxColor.WHITE, 0.01, true, function()
									{
										add(dialogueBox);
										camHUD.visible = true;
									}, true);
								});
								new FlxTimer().start(3.2, function(deadTime:FlxTimer)
								{
									FlxG.camera.fade(FlxColor.WHITE, 1.6, false);
								});
							}
						});
					}
					else
					{
						add(dialogueBox);
					}
				}
				else
					startCountdown();

				remove(black);
			}
		});
	}

	function tankIntro()
	{
		var cutsceneHandler:CutsceneHandler = new CutsceneHandler();
		if (!firstStart) {
			generateStaticArrows(0);
			generateStaticArrows(1);
			FlxTween.tween(camHUD, {alpha: 0}, .5, {onComplete: function(_) {
				camHUD.visible = false;
			}});
		}
		else
			camHUD.visible = false;

		var songName:String = Paths.formatToSongPath(SONG.song);
		dadGroup.alpha = 0.00001;
		//inCutscene = true; //this would stop the camera movement, oops

		var tankman:FlxSprite = new FlxSprite(-20, 320);
		tankman.frames = Paths.getSparrowAtlas('cutscenes/' + songName);
		tankman.antialiasing = ClientPrefs.globalAntialiasing;
		addBehindDad(tankman);
		cutsceneHandler.push(tankman);

		var tankman2:FlxSprite = new FlxSprite(16, 312);
		tankman2.antialiasing = ClientPrefs.globalAntialiasing;
		tankman2.alpha = 0.000001;
		cutsceneHandler.push(tankman2);
		var gfDance:FlxSprite = new FlxSprite(gf.x - 107, gf.y + 140);
		gfDance.antialiasing = ClientPrefs.globalAntialiasing;
		cutsceneHandler.push(gfDance);
		var gfCutscene:FlxSprite = new FlxSprite(gf.x - 104, gf.y + 122);
		gfCutscene.antialiasing = ClientPrefs.globalAntialiasing;
		cutsceneHandler.push(gfCutscene);
		var picoCutscene:FlxSprite = new FlxSprite(gf.x - 849, gf.y - 264);
		picoCutscene.antialiasing = ClientPrefs.globalAntialiasing;
		cutsceneHandler.push(picoCutscene);
		var boyfriendCutscene:FlxSprite = new FlxSprite(boyfriend.x + 5, boyfriend.y + 20);
		boyfriendCutscene.antialiasing = ClientPrefs.globalAntialiasing;
		cutsceneHandler.push(boyfriendCutscene);

		cutsceneHandler.finishCallback = function()
		{
			var timeForStuff:Float = Conductor.crochet / 1000 * 4.5;
			FlxG.sound.music.fadeOut(timeForStuff);
			FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom}, timeForStuff, {ease: FlxEase.quadInOut});
			moveCamera(true);

			if (firstStart) {
				generateStaticArrows(0, true);
				generateStaticArrows(1, true);
			}
			startCountdown();

			dadGroup.alpha = 1;
			boyfriend.animation.finishCallback = null;
			gf.animation.finishCallback = null;
			gf.dance();

			camHUD.visible = true;
			camHUD.alpha = 0;
			FlxTween.tween(camHUD, {alpha: 1}, .7);
		};

		camFollow.set(dad.x + 280, dad.y + 170);
		switch(songName)
		{
			case 'ugh':
				cutsceneHandler.endTime = 12;
				cutsceneHandler.music = 'DISTORTO';
				precacheList.set('wellWellWell', 'sound');
				precacheList.set('killYou', 'sound');
				precacheList.set('bfBeep', 'sound');

				var wellWellWell:FlxSound = new FlxSound().loadEmbedded(Paths.sound('wellWellWell'));
				FlxG.sound.list.add(wellWellWell);

				tankman.animation.addByPrefix('wellWell', 'TANK TALK 1 P1', 24, false);
				tankman.animation.addByPrefix('killYou', 'TANK TALK 1 P2', 24, false);
				tankman.animation.play('wellWell', true);
				FlxG.camera.zoom *= 1.2;

				// Well well well, what do we got here?
				cutsceneHandler.timer(0.1, function()
				{
					wellWellWell.play(true);
				});

				// Move camera to BF
				cutsceneHandler.timer(3, function()
				{
					camFollow.x += 750;
					camFollow.y += 100;
				});

				// Beep!
				cutsceneHandler.timer(4.5, function()
				{
					boyfriend.playAnim('singUP', true);
					boyfriend.specialAnim = true;
					FlxG.sound.play(Paths.sound('bfBeep'));
				});

				// Move camera to Tankman
				cutsceneHandler.timer(6, function()
				{
					camFollow.x -= 750;
					camFollow.y -= 100;

					// We should just kill you but... what the hell, it's been a boring day... let's see what you've got!
					tankman.animation.play('killYou', true);
					FlxG.sound.play(Paths.sound('killYou'));
				});

			case 'guns':
				cutsceneHandler.endTime = 11.5;
				cutsceneHandler.music = 'DISTORTO';
				tankman.x += 40;
				tankman.y += 10;
				precacheList.set('tankSong2', 'sound');

				var tightBars:FlxSound = new FlxSound().loadEmbedded(Paths.sound('tankSong2'));
				FlxG.sound.list.add(tightBars);

				tankman.animation.addByPrefix('tightBars', 'TANK TALK 2', 24, false);
				tankman.animation.play('tightBars', true);
				boyfriend.animation.curAnim.finish();

				cutsceneHandler.onStart = function()
				{
					tightBars.play(true);
					FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom * 1.2}, 4, {ease: FlxEase.quadInOut});
					FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom * 1.2 * 1.2}, 0.5, {ease: FlxEase.quadInOut, startDelay: 4});
					FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom * 1.2}, 1, {ease: FlxEase.quadInOut, startDelay: 4.5});
				};

				cutsceneHandler.timer(4, function()
				{
					gf.playAnim('sad', true);
					gf.animation.finishCallback = function(name:String)
					{
						gf.playAnim('sad', true);
					};
				});

			case 'stress':
				cutsceneHandler.endTime = 35.5;
				tankman.x -= 54;
				tankman.y -= 14;
				gfGroup.alpha = 0.00001;
				boyfriendGroup.alpha = 0.00001;
				camFollow.set(dad.x + 400, dad.y + 170);
				FlxTween.tween(FlxG.camera, {zoom: 0.9 * 1.2}, 1, {ease: FlxEase.quadInOut});
				foregroundSprites.forEach(function(spr:BGSprite)
				{
					spr.y += 100;
				});
				precacheList.set('stressCutscene', 'sound');

				tankman2.frames = Paths.getSparrowAtlas('cutscenes/stress2');
				addBehindDad(tankman2);

				if (!ClientPrefs.lowQuality)
				{
					gfDance.frames = Paths.getSparrowAtlas('characters/gfTankmen');
					gfDance.animation.addByPrefix('dance', 'GF Dancing at Gunpoint', 24, true);
					gfDance.animation.play('dance', true);
					addBehindGF(gfDance);
				}

				gfCutscene.frames = Paths.getSparrowAtlas('cutscenes/stressGF');
				gfCutscene.animation.addByPrefix('dieBitch', 'GF STARTS TO TURN PART 1', 24, false);
				gfCutscene.animation.addByPrefix('getRektLmao', 'GF STARTS TO TURN PART 2', 24, false);
				gfCutscene.animation.play('dieBitch', true);
				gfCutscene.animation.pause();
				addBehindGF(gfCutscene);
				if (!ClientPrefs.lowQuality)
				{
					gfCutscene.alpha = 0.00001;
				}

				picoCutscene.frames = AtlasFrameMaker.construct('cutscenes/stressPico');
				picoCutscene.animation.addByPrefix('anim', 'Pico Badass', 24, false);
				addBehindGF(picoCutscene);
				picoCutscene.alpha = 0.00001;

				boyfriendCutscene.frames = Paths.getSparrowAtlas('characters/BOYFRIEND');
				boyfriendCutscene.animation.addByPrefix('idle', 'BF idle dance', 24, false);
				boyfriendCutscene.animation.play('idle', true);
				boyfriendCutscene.animation.curAnim.finish();
				addBehindBF(boyfriendCutscene);

				var cutsceneSnd:FlxSound = new FlxSound().loadEmbedded(Paths.sound('stressCutscene'));
				FlxG.sound.list.add(cutsceneSnd);

				tankman.animation.addByPrefix('godEffingDamnIt', 'TANK TALK 3', 24, false);
				tankman.animation.play('godEffingDamnIt', true);

				var calledTimes:Int = 0;
				var zoomBack:Void->Void = function()
				{
					var camPosX:Float = 630;
					var camPosY:Float = 425;
					camFollow.set(camPosX, camPosY);
					camFollowPos.setPosition(camPosX, camPosY);
					FlxG.camera.zoom = 0.8;
					cameraSpeed = 1;

					calledTimes++;
					if (calledTimes > 1)
					{
						foregroundSprites.forEach(function(spr:BGSprite)
						{
							spr.y -= 100;
						});
					}
				}

				cutsceneHandler.onStart = function()
				{
					cutsceneSnd.play(true);
				};

				cutsceneHandler.timer(15.2, function()
				{
					FlxTween.tween(camFollow, {x: 650, y: 300}, 1, {ease: FlxEase.sineOut});
					FlxTween.tween(FlxG.camera, {zoom: 0.9 * 1.2 * 1.2}, 2.25, {ease: FlxEase.quadInOut});

					gfDance.visible = false;
					gfCutscene.alpha = 1;
					gfCutscene.animation.play('dieBitch', true);
					gfCutscene.animation.finishCallback = function(name:String)
					{
						if(name == 'dieBitch') //Next part
						{
							gfCutscene.animation.play('getRektLmao', true);
							gfCutscene.offset.set(224, 445);
						}
						else
						{
							gfCutscene.visible = false;
							picoCutscene.alpha = 1;
							picoCutscene.animation.play('anim', true);

							boyfriendGroup.alpha = 1;
							boyfriendCutscene.visible = false;
							boyfriend.playAnim('bfCatch', true);
							boyfriend.animation.finishCallback = function(name:String)
							{
								if(name != 'idle')
								{
									boyfriend.playAnim('idle', true);
									boyfriend.animation.curAnim.finish(); //Instantly goes to last frame
								}
							};

							picoCutscene.animation.finishCallback = function(name:String)
							{
								picoCutscene.visible = false;
								gfGroup.alpha = 1;
								picoCutscene.animation.finishCallback = null;
							};
							gfCutscene.animation.finishCallback = null;
						}
					};
				});

				cutsceneHandler.timer(17.5, function()
				{
					zoomBack();
				});

				cutsceneHandler.timer(19.5, function()
				{
					tankman2.animation.addByPrefix('lookWhoItIs', 'TANK TALK 3', 24, false);
					tankman2.animation.play('lookWhoItIs', true);
					tankman2.alpha = 1;
					tankman.visible = false;
				});

				cutsceneHandler.timer(20, function()
				{
					camFollow.set(dad.x + 500, dad.y + 170);
				});

				cutsceneHandler.timer(31.2, function()
				{
					boyfriend.playAnim('singUPmiss', true);
					boyfriend.animation.finishCallback = function(name:String)
					{
						if (name == 'singUPmiss')
						{
							boyfriend.playAnim('idle', true);
							boyfriend.animation.curAnim.finish(); //Instantly goes to last frame
						}
					};

					camFollow.set(boyfriend.x + 280, boyfriend.y + 200);
					cameraSpeed = 12;
					FlxTween.tween(FlxG.camera, {zoom: 0.9 * 1.2 * 1.2}, 0.25, {ease: FlxEase.elasticOut});
				});

				cutsceneHandler.timer(32.2, function()
				{
					zoomBack();
				});
		}
	}

	var startTimer:FlxTimer;
	var finishTimer:FlxTimer = null;

	// For being able to mess with the sprites on Lua
	public var countdownReady:FlxSprite;
	public var countdownSet:FlxSprite;
	public var countdownGo:FlxSprite;
	public static var startOnTime:Float = 0;

	function cacheCountdown()
	{
		var introAssets:Map<String, Array<String>> = new Map<String, Array<String>>();
		introAssets.set('default', ['ready', 'set', 'go']);
		introAssets.set('pixel', ['pixelUI/ready-pixel', 'pixelUI/set-pixel', 'pixelUI/date-pixel']);

		var introAlts:Array<String> = introAssets.get('default');
		if (isPixelStage) introAlts = introAssets.get('pixel');
		
		for (asset in introAlts)
			Paths.image(asset, 'shared');
		
		Paths.sound('intro3' + introSoundsSuffix);
		Paths.sound('intro2' + introSoundsSuffix);
		Paths.sound('intro1' + introSoundsSuffix);
		Paths.sound('introGo' + introSoundsSuffix);
	}

	public function startCountdown():Void
	{
		if(startedCountdown) {
			callOnLuas('onStartCountdown');
			return;
		}

		inCutscene = false;
		var ret:Dynamic = callOnLuas('onStartCountdown', [], false);
		if(ret != FunkinLua.Function_Stop) {
			if (skipCountdown || startOnTime > 0) skipArrowStartTween = true;

			generateStaticArrows(0);
			generateStaticArrows(1);
			for (i in 0...playerStrums.length) {
				setOnLuas('defaultPlayerStrumX' + i, playerStrums.members[i].x);
				setOnLuas('defaultPlayerStrumY' + i, playerStrums.members[i].y);
			}
			for (i in 0...opponentStrums.length) {
				setOnLuas('defaultOpponentStrumX' + i, opponentStrums.members[i].x);
				setOnLuas('defaultOpponentStrumY' + i, opponentStrums.members[i].y);
				//if(ClientPrefs.middleScroll) opponentStrums.members[i].visible = false;
			}

			startedCountdown = true;
			Conductor.songPosition = -Conductor.crochet * 5;
			setOnLuas('startedCountdown', true);
			callOnLuas('onCountdownStarted');

			var swagCounter:Int = 0;

			if(startOnTime < 0) startOnTime = 0;

			if (startOnTime > 0) {
				clearNotesBefore(startOnTime);
				setSongTime(startOnTime - 350);
				return;
			}
			else if (skipCountdown) {
				setSongTime(0);
				return;
			}
			
			var introAssets:Map<String, Array<String>> = new Map<String, Array<String>>();
			introAssets.set('default', ['ready', 'set', 'go']);
			introAssets.set('pixel', ['pixelUI/ready-pixel', 'pixelUI/set-pixel', 'pixelUI/date-pixel']);

			startTimer = new FlxTimer().start(Conductor.crochet / 1000 / playbackRate, function(tmr:FlxTimer) {
				charactersDance();

				var introAlts:Array<String> = introAssets.get('default');
				var antialias:Bool = ClientPrefs.globalAntialiasing;
				if(isPixelStage) {
					introAlts = introAssets.get('pixel');
					antialias = false;
				}

				// head bopping for bg characters on Mall
				if(curStage == 'mall') {
					if(!ClientPrefs.lowQuality)
						upperBoppers.dance(true);

					bottomBoppers.dance(true);
					santa.dance(true);
				}

				switch (swagCounter)
				{
					case 0:
						FlxG.sound.play(Paths.sound('intro3' + introSoundsSuffix), 0.6);
					case 1:
						countdownReady = new FlxSprite().loadGraphic(Paths.image(introAlts[0]));
						countdownReady.cameras = [camHUD];
						countdownReady.scrollFactor.set();
						countdownReady.updateHitbox();

						if (PlayState.isPixelStage)
							countdownReady.setGraphicSize(Std.int(countdownReady.width * daPixelZoom));

						countdownReady.screenCenter();
						countdownReady.antialiasing = antialias;
						insert(members.indexOf(notes), countdownReady);
						FlxTween.tween(countdownReady, {/*y: countdownReady.y + 100,*/ alpha: 0}, Conductor.crochet / 1000, {
							ease: FlxEase.cubeInOut,
							onComplete: function(twn:FlxTween)
							{
								remove(countdownReady);
								countdownReady.destroy();
							}
						});
						FlxG.sound.play(Paths.sound('intro2' + introSoundsSuffix), 0.6);
					case 2:
						countdownSet = new FlxSprite().loadGraphic(Paths.image(introAlts[1]));
						countdownSet.cameras = [camHUD];
						countdownSet.scrollFactor.set();

						if (PlayState.isPixelStage)
							countdownSet.setGraphicSize(Std.int(countdownSet.width * daPixelZoom));

						countdownSet.screenCenter();
						countdownSet.antialiasing = antialias;
						insert(members.indexOf(notes), countdownSet);
						FlxTween.tween(countdownSet, {/*y: countdownSet.y + 100,*/ alpha: 0}, Conductor.crochet / 1000, {
							ease: FlxEase.cubeInOut,
							onComplete: function(twn:FlxTween)
							{
								remove(countdownSet);
								countdownSet.destroy();
							}
						});
						FlxG.sound.play(Paths.sound('intro1' + introSoundsSuffix), 0.6);
					case 3:
						countdownGo = new FlxSprite().loadGraphic(Paths.image(introAlts[2]));
						countdownGo.cameras = [camHUD];
						countdownGo.scrollFactor.set();

						if (PlayState.isPixelStage)
							countdownGo.setGraphicSize(Std.int(countdownGo.width * daPixelZoom));

						countdownGo.updateHitbox();

						countdownGo.screenCenter();
						countdownGo.antialiasing = antialias;
						insert(members.indexOf(notes), countdownGo);
						FlxTween.tween(countdownGo, {/*y: countdownGo.y + 100,*/ alpha: 0}, Conductor.crochet / 1000, {
							ease: FlxEase.cubeInOut,
							onComplete: function(twn:FlxTween)
							{
								remove(countdownGo);
								countdownGo.destroy();
							}
						});
						FlxG.sound.play(Paths.sound('introGo' + introSoundsSuffix), 0.6);
					case 4:
				}

				notes.forEachAlive(function(note:Note) {
					if(ClientPrefs.opponentStrums || note.mustPress)
					{
						note.copyAlpha = false;
						note.alpha = note.multAlpha;
						if(ClientPrefs.middleScroll && !note.mustPress) {
							note.alpha *= 0.35;
						}
					}
				});
				callOnLuas('onCountdownTick', [swagCounter]);

				swagCounter += 1;
				// generateSong('fresh');
			}, 5);
		}
	}

	public function addBehindGF(obj:FlxObject)
	{
		insert(members.indexOf(gfGroup), obj);
	}
	public function addBehindBF(obj:FlxObject)
	{
		insert(members.indexOf(boyfriendGroup), obj);
	}
	public function addBehindDad (obj:FlxObject)
	{
		insert(members.indexOf(dadGroup), obj);
	}

	public function clearNotesBefore(time:Float)
	{
		var i:Int = unspawnNotes.length - 1;
		while (i >= 0) {
			var daNote:Note = unspawnNotes[i];
			if(daNote.strumTime - 350 < time)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;

				daNote.kill();
				unspawnNotes.remove(daNote);
				daNote.destroy();
			}
			--i;
		}

		i = notes.length - 1;
		while (i >= 0) {
			var daNote:Note = notes.members[i];
			if(daNote.strumTime - 350 < time)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;

				daNote.kill();
				notes.remove(daNote, true);
				daNote.destroy();
			}
			--i;
		}
	}

	public function setSongTime(time:Float)
	{
		if (time < 0) time = 0;

		Conductor.songPosition = songTime = time;

		FlxG.sound.music.time = time;
		FlxG.sound.music.pitch = playbackRate;
		if (time <= vocals.length) {
			vocals.time = time;
			vocals.pitch = playbackRate;
			FlxG.sound.music.play();
			vocals.play();
		}
		else
			FlxG.sound.music.play();
	}

	function startNextDialogue() {
		dialogueCount++;
		callOnLuas('onNextDialogue', [dialogueCount]);
	}

	function skipDialogue() {
		callOnLuas('onSkipDialogue', [dialogueCount]);
	}

	var previousFrameTime:Int = 0;
	var lastReportedPlayheadPosition:Int = 0;
	var songTime:Float = 0;

	function startSong():Void
	{
		startingSong = false;

		previousFrameTime = FlxG.game.ticks;
		lastReportedPlayheadPosition = 0;
		
		var music:FlxSound = FlxG.sound.music;
		music.loadEmbedded(Paths.inst(PlayState.SONG.song), false);
		music.onComplete = finishSong.bind();
		music.pitch = playbackRate;
		music.volume = 1;
		music.time = 0;
		music.play();
		vocals.play();
		
		if (startOnTime > 0) setSongTime(startOnTime - 500);
		startOnTime = 0;

		if (paused) {
			music.pause();
			vocals.pause();
		}

		// Song duration in a float, useful for the time left feature
		songLength = music.length;
		FlxTween.tween(timeBar, {alpha: 1}, 0.5, {ease: FlxEase.circOut});
		FlxTween.tween(timeTxt, {alpha: 1}, 0.5, {ease: FlxEase.circOut});

		switch(curStage)
		{
			case 'tank':
				if(!ClientPrefs.lowQuality) tankWatchtower.dance();
				foregroundSprites.forEach(function(spr:BGSprite)
				{
					spr.dance();
				});
		}

		changeDiscordPresence(false, true);
		setOnLuas('songLength', songLength);
		callOnLuas('onSongStart');
	}

	var debugNum:Int = 0;
	private var noteTypeMap:Map<String, Bool> = new Map<String, Bool>();
	private var eventPushedMap:Map<String, Bool> = new Map<String, Bool>();
	private function generateSong(dataPath:String):Void
	{
		// FlxG.log.add(ChartParser.parse());
		songSpeedType = ClientPrefs.getGameplaySetting('scrolltype','multiplicative');

		switch(songSpeedType)
		{
			case "multiplicative":
				songSpeed = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed', 1);
			case "constant":
				songSpeed = ClientPrefs.getGameplaySetting('scrollspeed', 1);
		}

		var songData = SONG;
		Conductor.changeBPM(songData.bpm);

		curSong = songData.song;

		// dirty but whatever
		var inst = Paths.inst(PlayState.SONG.song);
		songLength = inst != null ? inst.length : 0;

		if (SONG.needsVoices)
			vocals = new FlxSound().loadEmbedded(Paths.voices(PlayState.SONG.song));
		else
			vocals = new FlxSound();

		vocals.group = FlxG.sound.defaultMusicGroup;
		vocals.pitch = playbackRate;
		FlxG.sound.list.add(vocals);

		notes = new FlxTypedGroup<Note>();
		notes.camera = camHUD;
		insert(members.indexOf(strumLineNotes) + 1, notes);

		var noteData:Array<SwagSection>;

		// NEW SHIT
		noteData = songData.notes;

		var playerCounter:Int = 0;

		var daBeats:Int = 0; // Not exactly representative of 'daBeats' lol, just how much it has looped

		for (section in noteData)
		{
			for (songNotes in section.sectionNotes)
			{
				var daStrumTime:Float = songNotes[0];
				var daNoteData:Int = Std.int(songNotes[1] % 4);

				var gottaHitNote:Bool = section.mustHitSection;

				if (songNotes[1] > 3)
				{
					gottaHitNote = !section.mustHitSection;
				}

				var oldNote:Note;
				if (unspawnNotes.length > 0)
					oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];
				else
					oldNote = null;

				var fixedSus:Int = Math.round(songNotes[2] / Conductor.stepCrochet);

				var swagNote:Note = new Note(daStrumTime, daNoteData, oldNote);
				swagNote.mustPress = gottaHitNote;
				swagNote.sustainLength = fixedSus * Conductor.stepCrochet;
				swagNote.gfNote = (section.gfSection && (songNotes[1]<4));
				swagNote.noteType = songNotes[3];
				if(!Std.isOfType(songNotes[3], String)) swagNote.noteType = editors.ChartingState.noteTypeList[songNotes[3]]; //Backward compatibility + compatibility with Week 7 charts
				swagNote.scrollFactor.set();

				unspawnNotes.push(swagNote);

				if (fixedSus > 0) {
					for (susNote in 0...Math.floor(Math.max(fixedSus, 2))) {
						oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];

						var sustainNote:Note = new Note(daStrumTime + (Conductor.stepCrochet * susNote) + (Conductor.stepCrochet / FlxMath.roundDecimal(songSpeed, 2)), daNoteData, oldNote, true);
						sustainNote.mustPress = gottaHitNote;
						sustainNote.gfNote = (section.gfSection && (songNotes[1]<4));
						sustainNote.noteType = swagNote.noteType;
						sustainNote.scrollFactor.set();
						swagNote.tail.push(sustainNote);
						sustainNote.parent = swagNote;
						unspawnNotes.push(sustainNote);

						if (sustainNote.mustPress)
							sustainNote.x += FlxG.width / 2; // general offset
						else if (ClientPrefs.middleScroll) {
							sustainNote.x += 310;
							if (daNoteData > 1) //Up and Right
								sustainNote.x += FlxG.width / 2 + 25;
						}
					}
				}

				if (swagNote.mustPress)
				{
					swagNote.x += FlxG.width / 2; // general offset
				}
				else if(ClientPrefs.middleScroll)
				{
					swagNote.x += 310;
					if(daNoteData > 1) //Up and Right
					{
						swagNote.x += FlxG.width / 2 + 25;
					}
				}

				if(!noteTypeMap.exists(swagNote.noteType)) {
					noteTypeMap.set(swagNote.noteType, true);
				}
			}
			daBeats += 1;
		}

		var rawEvents:Array<Array<Dynamic>> = [];
		for (event in songData.events) //Event Notes
		{
			for (i in 0...event[1].length)
			{
				var newEventNote:Array<Dynamic> = [event[0], event[1][i][0], event[1][i][1], event[1][i][2]];
				rawEvents.push(newEventNote);

				var subEvent:EventNote = {
					strumTime: newEventNote[0] + ClientPrefs.noteOffset,
					event: newEventNote[1],
					value1: newEventNote[2],
					value2: newEventNote[3]
				};
				subEvent.strumTime -= eventNoteEarlyTrigger(subEvent);
				eventNotes.push(subEvent);
				eventPushed(subEvent);
			}
		}

		var songName:String = Paths.formatToSongPath(SONG.song);
		var file:String = Paths.json(songName + '/events');
		#if MODS_ALLOWED
		if (FileSystem.exists(Paths.modsJson(songName + '/events')) || FileSystem.exists(file)) {
		#else
		if (OpenFlAssets.exists(file)) {
		#end
			var eventsData:Array<Dynamic> = Song.loadFromJson('events', songName).events;
			for (event in eventsData) //Event Notes
			{
				for (i in 0...event[1].length)
				{
					var newEventNote:Array<Dynamic> = [event[0], event[1][i][0], event[1][i][1], event[1][i][2]];
					for (rawEvent in rawEvents) {
						if (newEventNote[0] == rawEvent[0] || newEventNote[1] == rawEvent[1] || newEventNote[2] == rawEvent[2]
							|| newEventNote[3] == rawEvent[3])
							continue; // don't make another if it already exists in the previous raw Events
					}

					var subEvent:EventNote = {
						strumTime: newEventNote[0] + ClientPrefs.noteOffset,
						event: newEventNote[1],
						value1: newEventNote[2],
						value2: newEventNote[3]
					};
					subEvent.strumTime -= eventNoteEarlyTrigger(subEvent);
					eventNotes.push(subEvent);
					eventPushed(subEvent);
				}
			}
		}
		rawEvents = null;

		// trace(unspawnNotes.length);
		// playerCounter += 1;

		unspawnNotes.sort(sortByShit);
		if (eventNotes.length > 1) eventNotes.sort(sortByTime);

		checkEventNote();
		generatedMusic = true;
	}

	function eventPushed(event:EventNote) {
		switch(event.event) {
			case 'Change Character':
				var charType:Int = 0;
				switch(event.value1.toLowerCase()) {
					case 'gf' | 'girlfriend' | '1':
						charType = 2;
					case 'dad' | 'opponent' | '0':
						charType = 1;
					default:
						charType = Std.parseInt(event.value1);
						if(Math.isNaN(charType)) charType = 0;
				}

				var newCharacter:String = event.value2;
				addCharacterToList(newCharacter, charType);

			case 'Dadbattle Spotlight':
				dadbattleBlack = new BGSprite(null, -800, -400, 0, 0);
				dadbattleBlack.makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
				dadbattleBlack.alpha = 0.25;
				dadbattleBlack.visible = false;
				add(dadbattleBlack);

				dadbattleLight = new BGSprite('spotlight', 400, -400);
				dadbattleLight.alpha = 0.375;
				dadbattleLight.blend = ADD;
				dadbattleLight.visible = false;

				dadbattleSmokes.alpha = 0.7;
				dadbattleSmokes.blend = ADD;
				dadbattleSmokes.visible = false;
				add(dadbattleLight);
				add(dadbattleSmokes);

				var offsetX = 200;
				var smoke:BGSprite = new BGSprite('smoke', -1550 + offsetX, 660 + FlxG.random.float(-20, 20), 1.2, 1.05);
				smoke.setGraphicSize(Std.int(smoke.width * FlxG.random.float(1.1, 1.22)));
				smoke.updateHitbox();
				smoke.velocity.x = FlxG.random.float(15, 22);
				smoke.active = true;
				dadbattleSmokes.add(smoke);
				var smoke:BGSprite = new BGSprite('smoke', 1550 + offsetX, 660 + FlxG.random.float(-20, 20), 1.2, 1.05);
				smoke.setGraphicSize(Std.int(smoke.width * FlxG.random.float(1.1, 1.22)));
				smoke.updateHitbox();
				smoke.velocity.x = FlxG.random.float(-15, -22);
				smoke.active = true;
				smoke.flipX = true;
				dadbattleSmokes.add(smoke);


			case 'Philly Glow':
				blammedLightsBlack = new FlxSprite(FlxG.width * -0.5, FlxG.height * -0.5).makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
				blammedLightsBlack.visible = false;
				insert(members.indexOf(phillyStreet), blammedLightsBlack);

				phillyWindowEvent = new BGSprite('philly/window', phillyWindow.x, phillyWindow.y, 0.3, 0.3);
				phillyWindowEvent.setGraphicSize(Std.int(phillyWindowEvent.width * 0.85));
				phillyWindowEvent.updateHitbox();
				phillyWindowEvent.visible = false;
				insert(members.indexOf(blammedLightsBlack) + 1, phillyWindowEvent);


				phillyGlowGradient = new PhillyGlow.PhillyGlowGradient(-400, 225); //This shit was refusing to properly load FlxGradient so fuck it
				phillyGlowGradient.visible = false;
				insert(members.indexOf(blammedLightsBlack) + 1, phillyGlowGradient);
				if(!ClientPrefs.flashing) phillyGlowGradient.intendedAlpha = 0.7;

				precacheList.set('philly/particle', 'image'); //precache particle image
				phillyGlowParticles = new FlxTypedGroup<PhillyGlow.PhillyGlowParticle>();
				phillyGlowParticles.visible = false;
				insert(members.indexOf(phillyGlowGradient) + 1, phillyGlowParticles);
		}

		if(!eventPushedMap.exists(event.event)) {
			eventPushedMap.set(event.event, true);
		}
	}

	function eventNoteEarlyTrigger(event:EventNote):Float {
		var returnedValue:Float = callOnLuas('eventEarlyTrigger', [event.event]);
		if(returnedValue != 0) {
			return returnedValue;
		}

		switch(event.event) {
			case 'Kill Henchmen': //Better timing so that the kill sound matches the beat intended
				return 280; //Plays 280ms before the actual position
		}
		return 0;
	}

	function sortByShit(Obj1:Note, Obj2:Note):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
	}

	function sortByTime(Obj1:EventNote, Obj2:EventNote):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
	}

	public var skipArrowStartTween:Bool = false; //for lua
	public function generateStaticArrows(player:Int, arrowStartTween:Bool = false):Void
	{
		var grp = player == 1 ? playerStrums : opponentStrums;
		var targetAlpha:Float = 1;
		if (player < 1) {
			if(!ClientPrefs.opponentStrums) targetAlpha = 0;
			else if(ClientPrefs.middleScroll) targetAlpha = 0.35;
		}

		for (i in grp.members.length...4) {
			// FlxG.log.add(i);

			var babyArrow:StrumNote = new StrumNote(ClientPrefs.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X, strumLine.y, i, player);
			babyArrow.downScroll = ClientPrefs.downScroll;
			babyArrow.alpha = targetAlpha;

			if (player < 1 && ClientPrefs.middleScroll) {
				babyArrow.x += 310;
				if(i > 1) { //Up and Right
					babyArrow.x += FlxG.width / 2 + 25;
				}
			}

			grp.add(babyArrow);
			strumLineNotes.add(babyArrow);
			babyArrow.postAddedToGroup();
		}

		if (arrowStartTween || ((!isStoryMode || restarted || firstStart || deathCounter > 0) && !skipArrowStartTween)) {
			for (i in 0...grp.members.length) {
				var babyArrow:StrumNote = grp.members[i];
				if (babyArrow == null) continue;

				//babyArrow.y -= 10;
				babyArrow.alpha = 0;
				FlxTween.tween(babyArrow, {/*y: babyArrow.y + 10,*/ alpha: targetAlpha}, 1, {ease: FlxEase.circOut, startDelay: 0.5 + (0.2 * i)});
			}
		}
	}

	override function openSubState(SubState:FlxSubState)
	{
		if (paused)
		{
			if (FlxG.sound.music != null)
			{
				FlxG.sound.music.pause();
				vocals.pause();
			}
			cleanupLuas();

			if (startTimer != null && !startTimer.finished)
				startTimer.active = false;
			if (finishTimer != null && !finishTimer.finished)
				finishTimer.active = false;
			if (songSpeedTween != null)
				songSpeedTween.active = false;

			if(carTimer != null) carTimer.active = false;

			var chars:Array<Character> = [boyfriend, gf, dad];
			for (char in chars) {
				if(char != null && char.colorTween != null) {
					char.colorTween.active = false;
				}
			}

			for (tween in modchartTweens) {
				tween.active = false;
			}
			for (timer in modchartTimers) {
				timer.active = false;
			}
		}

		super.openSubState(SubState);
	}

	override function closeSubState()
	{
		if (paused)
		{
			if (FlxG.sound.music != null && !startingSong)
				resyncVocals();

			if (startTimer != null && !startTimer.finished)
				startTimer.active = true;
			if (finishTimer != null && !finishTimer.finished)
				finishTimer.active = true;
			if (songSpeedTween != null)
				songSpeedTween.active = true;

			if(carTimer != null) carTimer.active = true;

			var chars:Array<Character> = [boyfriend, gf, dad];
			for (char in chars) {
				if(char != null && char.colorTween != null) {
					char.colorTween.active = true;
				}
			}

			for (tween in modchartTweens) {
				tween.active = true;
			}
			for (timer in modchartTimers) {
				timer.active = true;
			}
			paused = false;
			callOnLuas('onResume');

			changeDiscordPresence(false, true);
		}

		super.closeSubState();
	}

	override public function onFocus():Void
	{
		if (health > 0 && !paused)
			changeDiscordPresence(false, true);

		super.onFocus();
	}

	override public function onFocusLost():Void
	{
		if (health > 0 && !paused) {
			cleanupLuas();
			if (!ClientPrefs.autoPausePlayState || !tryPause())
				changeDiscordPresence(FlxG.autoPause, true);
		}

		super.onFocusLost();
	}

	function resyncVocals(resync:Bool = true):Void
	{
		if (finishTimer != null || (transitioning && endingSong)) return;
		Conductor.songPosition = FlxG.sound.music.time;

		FlxG.sound.music.pitch = playbackRate;
		if (Conductor.songPosition <= vocals.length) {
			vocals.pitch = playbackRate;
			if (vocals.vorbis == null || resync) vocals.time = Conductor.songPosition;
			if (!vocals.playing) vocals.play();
		}
		if (!FlxG.sound.music.playing) FlxG.sound.music.play();
	}

	public var paused:Bool = false;
	public var canReset:Bool = true;
	var startedCountdown:Bool = false;
	var canPause:Bool = true;
	var limoSpeed:Float = 0;

	override function update(elapsed:Float) {
		/*if (FlxG.keys.justPressed.NINE) {
			iconP1.swapOldIcon();
		}*/
		
		callOnLuas('onUpdate', [elapsed]);

		if (controls.PAUSE)
			tryPause();

		if (FlxG.keys.anyJustPressed(debugKeysChart) && !endingSong && !inCutscene)
			openChartEditor();

		if (FlxG.keys.anyJustPressed(debugKeysCharacter) && !endingSong && !inCutscene) {
			persistentUpdate = false;
			paused = true;
			cancelMusicFadeTween();
			MusicBeatState.switchState(new CharacterEditorState(SONG.player2));
		}

		updateStage(elapsed);

		if (startedCountdown) Conductor.songPosition += elapsed * 1000 * playbackRate;

		if (!inCutscene) {
			var lerpVal:Float = CoolUtil.boundTo(elapsed * 2.4 * cameraSpeed * playbackRate, 0, 1);
			camFollowPos.setPosition(
				FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal),
				FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal)
			);

			if (!startingSong && !endingSong && boyfriend.animation.curAnim != null && boyfriend.animation.curAnim.name.startsWith('idle')) {
				boyfriendIdleTime += elapsed;
				if (boyfriendIdleTime >= 0.15) // Kind of a mercy thing for making the achievement easier to get as it's apparently frustrating to some playerss
					boyfriendIdled = true;
			}
			else
				boyfriendIdleTime = 0;
		}

		checkEventNote();

		super.update(elapsed);

		//FlxG.watch.addQuick("VOLLeft", vocals.amplitudeLeft);
		//FlxG.watch.addQuick("VOLRight", vocals.amplitudeRight);
		FlxG.watch.addQuick("secShit", curSection);
		FlxG.watch.addQuick("beatShit", curBeat);
		FlxG.watch.addQuick("stepShit", curStep);

		setOnLuas('curDecStep', curDecStep);
		setOnLuas('curDecBeat', curDecBeat);

		if (startingSong) {
			if (startedCountdown && Conductor.songPosition >= 0)
				startSong();
			else if (!startedCountdown)
				Conductor.songPosition = -Conductor.crochet * 5;
		}
		else {
			if (!paused) {
				songTime += FlxG.game.ticks - previousFrameTime;
				previousFrameTime = FlxG.game.ticks;

				// Interpolation type beat
				if (Conductor.lastSongPos != Conductor.songPosition) {
					songTime = (songTime + Conductor.songPosition) / 2;
					Conductor.lastSongPos = Conductor.songPosition;
					// Conductor.songPosition += elapsed * 1000;
					// trace('MISSED FRAME');
				}

				if (updateTime) {
					var curTime:Float = Math.max(0, Conductor.songPosition - ClientPrefs.noteOffset);
					songPercent = (curTime / songLength);

					if (ClientPrefs.timeBarType != 'Song Name') {
						var songCalc:Float = (songLength - curTime);
						if (ClientPrefs.timeBarType == 'Time Elapsed') songCalc = curTime;

						var secondsTotal:Int = Math.floor(Math.max(0, songCalc / 1000));
						timeTxt.text = FlxStringUtil.formatTime(secondsTotal, false);
					}
				}
			}

			// Conductor.lastSongPos = FlxG.sound.music.time;
		}

		if (camZooming) {
			FlxG.camera.zoom = FlxMath.lerp(defaultCamZoom, FlxG.camera.zoom, CoolUtil.boundTo(1 - (elapsed * 3.125 * camZoomingDecay * playbackRate), 0, 1));
			camHUD.zoom = FlxMath.lerp(1, camHUD.zoom, CoolUtil.boundTo(1 - (elapsed * 3.125 * camZoomingDecay * playbackRate), 0, 1));
		}

		if (botplayTxt.visible) {
			botplaySine += 180 * elapsed;
			botplayTxt.alpha = 1 - Math.sin((Math.PI * botplaySine) / 180);
		}

		if (health > 2)
			health = 2;

		// RESET = Quick Game Over Screen
		if (!ClientPrefs.noReset && controls.RESET && canReset && !inCutscene && startedCountdown && !endingSong) {
			trace("RESET = True");
			health = 0;
		}
		doDeathCheck();

		if (unspawnNotes[0] != null) {
			var time:Float = spawnTime;
			if (songSpeed < 1) time /= songSpeed;
			if (unspawnNotes[0].multSpeed < 1) time /= unspawnNotes[0].multSpeed;

			while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.songPosition < time) {
				var dunceNote:Note = unspawnNotes[0];
				notes.insert(0, dunceNote);
				dunceNote.spawned = true;

				callOnLuas('onSpawnNote', [notes.members.indexOf(dunceNote), dunceNote.noteData, dunceNote.noteType, dunceNote.isSustainNote]);

				var index:Int = unspawnNotes.indexOf(dunceNote);
				unspawnNotes.splice(index, 1);
			}
		}

		if (generatedMusic && !inCutscene) {
			processInputs(elapsed);

			if (!boyfriend.stunned && boyfriend.animation.curAnim != null && (cpuControlled || !keysPressed.contains(true) || endingSong)) {
				var canDance = boyfriend.animation.curAnim.name.startsWith('sing') && !boyfriend.animation.curAnim.name.endsWith('miss');
				if (boyfriend.holdTimer > Conductor.stepCrochet * (0.0011 / playbackRate) * boyfriend.singDuration && canDance)
					boyfriend.dance();
			}

			if (startedCountdown) {
				renderNotes();
			}
			else {
				notes.forEachAlive(function(daNote:Note) {
					daNote.canBeHit = false;
					daNote.wasGoodHit = false;
				});
			}
		}

		var mult:Float = FlxMath.lerp(1, iconP1.scale.x, CoolUtil.boundTo(1 - (elapsed * 9 * playbackRate), 0, 1));
		iconP1.scale.set(mult, mult);
		iconP1.updateHitbox();

		var mult:Float = FlxMath.lerp(1, iconP2.scale.x, CoolUtil.boundTo(1 - (elapsed * 9 * playbackRate), 0, 1));
		iconP2.scale.set(mult, mult);
		iconP2.updateHitbox();

		var iconOffset:Int = 26;

		iconP1.x = healthBar.x + (healthBar.width * (FlxMath.remapToRange(healthBar.percent, 0, 100, 100, 0) * 0.01)) + (150 * iconP1.scale.x - 150) / 2 - iconOffset;
		iconP2.x = healthBar.x + (healthBar.width * (FlxMath.remapToRange(healthBar.percent, 0, 100, 100, 0) * 0.01)) - (150 * iconP2.scale.x) / 2 - iconOffset * 2;

		if (healthBar.percent < 20) {
			iconP1.setState(1);
			iconP2.setState(2);
		}
		else if (healthBar.percent > 80) {
			iconP1.setState(2);
			iconP2.setState(1);
		}
		else {
			iconP1.setState(0);
			iconP2.setState(0);
		}

		setOnLuas('cameraX', camFollowPos.x);
		setOnLuas('cameraY', camFollowPos.y);
		setOnLuas('botPlay', cpuControlled);
		callOnLuas('onUpdatePost', [elapsed]);

		/*
		#if debug
		if (!endingSong && !startingSong) {
			if (FlxG.keys.justPressed.ONE) {
				KillNotes();
				FlxG.sound.music.onComplete();
			}
			if(FlxG.keys.justPressed.TWO) { //Go 10 seconds into the future :O
				setSongTime(Conductor.songPosition + 10000);
				clearNotesBefore(Conductor.songPosition);
			}
		}
		#end
		*/
	}

	function renderNotes():Void {
		var fakeCrochet:Float = (60 / SONG.bpm) * 1000;
		notes.forEachAlive(function(daNote:Note) {
			var mustPress = daNote.mustPress;
			var ignoreNote = daNote.ignoreNote;
			var wasGoodHit = daNote.wasGoodHit;
			var isSus = daNote.isSustainNote;
			var isSusEnd = isSus && daNote.animation.curAnim != null && daNote.animation.curAnim.name.endsWith('end');
			var prevNote = daNote.prevNote;

			var missed = daNote.tooLate || daNote.hasMissed || (isSus && (daNote.parent == null || daNote.parent.hasMissed));

			var strumGroup:FlxTypedGroup<StrumNote> = mustPress ? playerStrums : opponentStrums;
			var strum:StrumNote = strumGroup.members[daNote.noteData];
			if (strum == null) { // fuck it
				daNote.kill();
				notes.remove(daNote, true);
				daNote.destroy();
				return;
			}

			var strumX:Float = strum.x + daNote.offsetX;
			var strumY:Float = strum.y + daNote.offsetY;
			var strumAngle:Float = strum.angle + daNote.offsetAngle;
			var strumAlpha:Float = strum.alpha * daNote.multAlpha * (missed ? .5 : 1);
			var strumDirection:Float = strum.direction;
			var strumScroll:Bool = strum.downScroll;

			var angleDir = strumDirection * Math.PI / 180;

			daNote.distance = (0.45 * (Conductor.songPosition - daNote.strumTime) * songSpeed * daNote.multSpeed);
			if (!strumScroll) daNote.distance = -daNote.distance;

			if (daNote.copyAngle)
				daNote.angle = strumDirection - 90 + strumAngle;

			if (daNote.copyAlpha)
				daNote.alpha = strumAlpha;

			if (daNote.copyX)
				daNote.x = strumX + Math.cos(angleDir) * daNote.distance;

			if (daNote.copyY) {
				daNote.y = strumY + Math.sin(angleDir) * daNote.distance;

				//Jesus fuck this took me so much mother fucking time AAAAAAAAAA
				if (strumScroll && isSus) {
					if (isSusEnd) {
						daNote.y += 10.5 * (fakeCrochet / 400) * 1.5 * songSpeed + (46 * (songSpeed - 1));
						daNote.y -= 46 * (1 - (fakeCrochet / 600)) * songSpeed;

						if (PlayState.isPixelStage)
							daNote.y += 8 + (6 - daNote.originalHeightForCalcs) * daPixelZoom;
						else
							daNote.y -= 19;
					}
					daNote.y += (Note.swagWidth / 2) - (60.5 * (songSpeed - 1));
					daNote.y += 27.5 * ((SONG.bpm / 100) - 1) * (songSpeed - 1);
				}
			}

			var center = strumY + Note.swagWidth / 2;
			if (strum.sustainReduce && isSus && (mustPress || !ignoreNote)
				&& (!mustPress || (wasGoodHit || (prevNote.wasGoodHit && !missed && !daNote.canBeHit))))
			{
				if (strumScroll ?
					(daNote.y - daNote.offset.y * daNote.scale.y + daNote.height >= center) :
					(daNote.y + daNote.offset.y * daNote.scale.y <= center)
				) {
					var swagRect = daNote.clipRect;
					if (swagRect == null) swagRect = FlxRect.get(0, 0, daNote.frameWidth, daNote.frameHeight);
					else swagRect.set(0, 0, daNote.frameWidth, daNote.frameHeight);

					if (strumScroll) {
						swagRect.height = (center - daNote.y) / daNote.scale.y;
						swagRect.y = daNote.frameHeight - swagRect.height;
					}
					else {
						swagRect.y = (center - daNote.y) / daNote.scale.y;
						swagRect.height -= swagRect.y;
					}

					daNote.clipRect = swagRect;
				}
			}

			// Kill extremely late notes and cause misses
			if (Conductor.songPosition > noteKillOffset + daNote.strumTime) {
				if (mustPress && !cpuControlled && !ignoreNote && !endingSong && (missed || !wasGoodHit))
					noteMiss(daNote);

				daNote.active = false;
				daNote.visible = false;

				daNote.kill();
				notes.remove(daNote, true);
				daNote.destroy();
			}
		});
	}

	function tryPause():Bool {
		if (startedCountdown && canPause) {
			var ret:Dynamic = callOnLuas('onPause', [], false);
			if (ret != FunkinLua.Function_Stop) {
				openPauseMenu();
				return true;
			}
		}
		return false;
	}

	function openPauseMenu() {
		for (i in 0...keysPressed.length) {
			if (keysPressed[i]) inputRelease(i);
		}

		persistentUpdate = false;
		persistentDraw = true;
		paused = true;

		// 1 / 1000 chance for Gitaroo Man easter egg
		/*if (FlxG.random.bool(0.1))
		{
			// gitaroo man easter egg
			cancelMusicFadeTween();
			MusicBeatState.switchState(new GitarooPause());
		}
		else {*/
		if(FlxG.sound.music != null) {
			FlxG.sound.music.pause();
			vocals.pause();
		}
		openSubState(new PauseSubState(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));
		//}

		changeDiscordPresence(true, true);
	}

	function openChartEditor()
	{
		persistentUpdate = false;
		paused = true;
		cancelMusicFadeTween();
		MusicBeatState.switchState(new ChartingState());
		chartingMode = true;

		#if desktop
		presenceChangedByLua = true;
		DiscordClient.changePresence("Chart Editor", null, null, true);
		#end
	}

	public var isDead:Bool = false; //Don't mess with this on Lua!!!
	function doDeathCheck(?skipHealthCheck:Bool = false) {
		if (((skipHealthCheck && instakillOnMiss) || health <= 0) && !practiceMode && !isDead)
		{
			var ret:Dynamic = callOnLuas('onGameOver', [], false);
			if(ret != FunkinLua.Function_Stop) {
				boyfriend.stunned = true;
				deathCounter++;

				paused = true;

				vocals.stop();
				FlxG.sound.music.stop();

				persistentUpdate = false;
				persistentDraw = false;
				for (tween in modchartTweens) {
					tween.active = true;
				}
				for (timer in modchartTimers) {
					timer.active = true;
				}
				openSubState(new GameOverSubstate(boyfriend.getScreenPosition().x - boyfriend.positionArray[0], boyfriend.getScreenPosition().y - boyfriend.positionArray[1], camFollowPos.x, camFollowPos.y));

				// MusicBeatState.switchState(new GameOverState(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));

				isDead = true;
				changeDiscordPresence("Game Over", false, true);
				return true;
			}
		}
		return false;
	}

	public function checkEventNote() {
		while(eventNotes.length > 0) {
			var leStrumTime:Float = eventNotes[0].strumTime;
			if(Conductor.songPosition < leStrumTime) {
				break;
			}

			var value1:String = '';
			if(eventNotes[0].value1 != null)
				value1 = eventNotes[0].value1;

			var value2:String = '';
			if(eventNotes[0].value2 != null)
				value2 = eventNotes[0].value2;

			triggerEventNote(eventNotes[0].event, value1, value2);
			eventNotes.shift();
		}
	}

	public function triggerEventNote(eventName:String, value1:String, value2:String) {
		switch(eventName) {
			case 'Dadbattle Spotlight':
				var val:Null<Int> = Std.parseInt(value1);
				if(val == null) val = 0;

				switch(Std.parseInt(value1))
				{
					case 1, 2, 3: //enable and target dad
						if(val == 1) //enable
						{
							dadbattleBlack.visible = true;
							dadbattleLight.visible = true;
							dadbattleSmokes.visible = true;
							defaultCamZoom += 0.12;
						}

						var who:Character = dad;
						if(val > 2) who = boyfriend;
						//2 only targets dad
						dadbattleLight.alpha = 0;
						new FlxTimer().start(0.12, function(tmr:FlxTimer) {
							dadbattleLight.alpha = 0.375;
						});
						dadbattleLight.setPosition(who.getGraphicMidpoint().x - dadbattleLight.width / 2, who.y + who.height - dadbattleLight.height + 50);

					default:
						dadbattleBlack.visible = false;
						dadbattleLight.visible = false;
						defaultCamZoom -= 0.12;
						FlxTween.tween(dadbattleSmokes, {alpha: 0}, 1, {onComplete: function(twn:FlxTween)
						{
							dadbattleSmokes.visible = false;
						}});
				}

			case 'Hey!':
				var value:Int = 2;
				switch(value1.toLowerCase().trim()) {
					case 'bf' | 'boyfriend' | '0':
						value = 0;
					case 'gf' | 'girlfriend' | '1':
						value = 1;
				}

				var time:Float = Std.parseFloat(value2);
				if(Math.isNaN(time) || time <= 0) time = 0.6;

				if(value != 0) {
					if(dad.curCharacter.startsWith('gf')) { //Tutorial GF is actually Dad! The GF is an imposter!! ding ding ding ding ding ding ding, dindinding, end my suffering
						dad.playAnim('cheer', true);
						dad.specialAnim = true;
						dad.heyTimer = time;
					} else if (gf != null) {
						gf.playAnim('cheer', true);
						gf.specialAnim = true;
						gf.heyTimer = time;
					}

					if(curStage == 'mall') {
						bottomBoppers.animation.play('hey', true);
						heyTimer = time;
					}
				}
				if(value != 1) {
					boyfriend.playAnim('hey', true);
					boyfriend.specialAnim = true;
					boyfriend.heyTimer = time;
				}

			case 'Set GF Speed':
				var value:Int = Std.parseInt(value1);
				if(Math.isNaN(value) || value < 1) value = 1;
				gfSpeed = value;

			case 'Philly Glow':
				var lightId:Int = Std.parseInt(value1);
				if(Math.isNaN(lightId)) lightId = 0;

				var doFlash:Void->Void = function() {
					var color:FlxColor = FlxColor.WHITE;
					if(!ClientPrefs.flashing) color.alphaFloat = 0.5;

					FlxG.camera.flash(color, 0.15, null, true);
				};

				var chars:Array<Character> = [boyfriend, gf, dad];
				switch(lightId)
				{
					case 0:
						if(phillyGlowGradient.visible)
						{
							doFlash();
							if(ClientPrefs.camZooms)
							{
								FlxG.camera.zoom += 0.5;
								camHUD.zoom += 0.1;
							}

							blammedLightsBlack.visible = false;
							phillyWindowEvent.visible = false;
							phillyGlowGradient.visible = false;
							phillyGlowParticles.visible = false;
							curLightEvent = -1;

							for (who in chars)
							{
								who.color = FlxColor.WHITE;
							}
							phillyStreet.color = FlxColor.WHITE;
						}

					case 1: //turn on
						curLightEvent = FlxG.random.int(0, phillyLightsColors.length-1, [curLightEvent]);
						var color:FlxColor = phillyLightsColors[curLightEvent];

						if(!phillyGlowGradient.visible)
						{
							doFlash();
							if(ClientPrefs.camZooms)
							{
								FlxG.camera.zoom += 0.5;
								camHUD.zoom += 0.1;
							}

							blammedLightsBlack.visible = true;
							blammedLightsBlack.alpha = 1;
							phillyWindowEvent.visible = true;
							phillyGlowGradient.visible = true;
							phillyGlowParticles.visible = true;
						}
						else if(ClientPrefs.flashing)
						{
							var colorButLower:FlxColor = color;
							colorButLower.alphaFloat = 0.25;
							FlxG.camera.flash(colorButLower, 0.5, null, true);
						}

						var charColor:FlxColor = color;
						if(!ClientPrefs.flashing) charColor.saturation *= 0.5;
						else charColor.saturation *= 0.75;

						for (who in chars)
						{
							who.color = charColor;
						}
						phillyGlowParticles.forEachAlive(function(particle:PhillyGlow.PhillyGlowParticle)
						{
							particle.color = color;
						});
						phillyGlowGradient.color = color;
						phillyWindowEvent.color = color;

						color.brightness *= 0.5;
						phillyStreet.color = color;

					case 2: // spawn particles
						if(!ClientPrefs.lowQuality)
						{
							var particlesNum:Int = FlxG.random.int(8, 12);
							var width:Float = (2000 / particlesNum);
							var color:FlxColor = phillyLightsColors[curLightEvent];
							for (j in 0...3)
							{
								for (i in 0...particlesNum)
								{
									var particle:PhillyGlow.PhillyGlowParticle = new PhillyGlow.PhillyGlowParticle(-400 + width * i + FlxG.random.float(-width / 5, width / 5), phillyGlowGradient.originalY + 200 + (FlxG.random.float(0, 125) + j * 40), color);
									phillyGlowParticles.add(particle);
								}
							}
						}
						phillyGlowGradient.bop();
				}

			case 'Kill Henchmen':
				killHenchmen();

			case 'Add Camera Zoom':
				if(ClientPrefs.camZooms && FlxG.camera.zoom < 1.35) {
					var camZoom:Float = Std.parseFloat(value1);
					var hudZoom:Float = Std.parseFloat(value2);
					if(Math.isNaN(camZoom)) camZoom = 0.015;
					if(Math.isNaN(hudZoom)) hudZoom = 0.03;

					FlxG.camera.zoom += camZoom;
					camHUD.zoom += hudZoom;
				}

			case 'Trigger BG Ghouls':
				if(curStage == 'schoolEvil' && !ClientPrefs.lowQuality) {
					bgGhouls.dance(true);
					bgGhouls.visible = true;
				}

			case 'Play Animation':
				//trace('Anim to play: ' + value1);
				var char:Character = dad;
				switch(value2.toLowerCase().trim()) {
					case 'bf' | 'boyfriend':
						char = boyfriend;
					case 'gf' | 'girlfriend':
						char = gf;
					default:
						var val2:Int = Std.parseInt(value2);
						if(Math.isNaN(val2)) val2 = 0;

						switch(val2) {
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null)
				{
					char.playAnim(value1, true);
					char.specialAnim = true;
				}

			case 'Camera Follow Pos':
				if(camFollow != null)
				{
					var val1:Float = Std.parseFloat(value1);
					var val2:Float = Std.parseFloat(value2);
					if(Math.isNaN(val1)) val1 = 0;
					if(Math.isNaN(val2)) val2 = 0;

					isCameraOnForcedPos = false;
					if(!Math.isNaN(Std.parseFloat(value1)) || !Math.isNaN(Std.parseFloat(value2))) {
						camFollow.x = val1;
						camFollow.y = val2;
						isCameraOnForcedPos = true;
					}
				}

			case 'Alt Idle Animation':
				var char:Character = dad;
				switch(value1.toLowerCase().trim()) {
					case 'gf' | 'girlfriend':
						char = gf;
					case 'boyfriend' | 'bf':
						char = boyfriend;
					default:
						var val:Int = Std.parseInt(value1);
						if(Math.isNaN(val)) val = 0;

						switch(val) {
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null) {
					char.idleSuffix = value2;
					char.recalculateDanceIdle();
				}

			case 'Screen Shake':
				var valuesArray:Array<String> = [value1, value2];
				var targetsArray:Array<FlxCamera> = [camGame, camHUD];
				for (i in 0...targetsArray.length) {
					var split:Array<String> = valuesArray[i].split(',');
					var duration:Float = 0;
					var intensity:Float = 0;
					if(split[0] != null) duration = Std.parseFloat(split[0].trim());
					if(split[1] != null) intensity = Std.parseFloat(split[1].trim());
					if(Math.isNaN(duration)) duration = 0;
					if(Math.isNaN(intensity)) intensity = 0;

					if(duration > 0 && intensity != 0) {
						targetsArray[i].shake(intensity, duration);
					}
				}


			case 'Change Character':
				var charType:Int = 0;
				switch(value1.toLowerCase().trim()) {
					case 'gf' | 'girlfriend':
						charType = 2;
					case 'dad' | 'opponent':
						charType = 1;
					default:
						charType = Std.parseInt(value1);
						if(Math.isNaN(charType)) charType = 0;
				}

				switch(charType) {
					case 0:
						if(boyfriend.curCharacter != value2) {
							if(!boyfriendMap.exists(value2)) {
								addCharacterToList(value2, charType);
							}

							var lastAlpha:Float = boyfriend.alpha;
							boyfriend.alpha = 0.00001;
							boyfriend = boyfriendMap.get(value2);
							boyfriend.alpha = lastAlpha;
							iconP1.changeIcon(boyfriend.healthIcon);
						}
						setOnLuas('boyfriendName', boyfriend.curCharacter);

					case 1:
						if(dad.curCharacter != value2) {
							if(!dadMap.exists(value2)) {
								addCharacterToList(value2, charType);
							}

							var wasGf:Bool = dad.curCharacter.startsWith('gf');
							var lastAlpha:Float = dad.alpha;
							dad.alpha = 0.00001;
							dad = dadMap.get(value2);
							if(!dad.curCharacter.startsWith('gf')) {
								if(wasGf && gf != null) {
									gf.visible = true;
								}
							} else if(gf != null) {
								gf.visible = false;
							}
							dad.alpha = lastAlpha;
							iconP2.changeIcon(dad.healthIcon);
						}
						setOnLuas('dadName', dad.curCharacter);

					case 2:
						if(gf != null)
						{
							if(gf.curCharacter != value2)
							{
								if(!gfMap.exists(value2))
								{
									addCharacterToList(value2, charType);
								}

								var lastAlpha:Float = gf.alpha;
								gf.alpha = 0.00001;
								gf = gfMap.get(value2);
								gf.alpha = lastAlpha;
							}
							setOnLuas('gfName', gf.curCharacter);
						}
				}
				reloadHealthBarColors();

			case 'BG Freaks Expression':
				if(bgGirls != null) bgGirls.swapDanceType();

			case 'Change Scroll Speed':
				if (songSpeedType == "constant")
					return;
				var val1:Float = Std.parseFloat(value1);
				var val2:Float = Std.parseFloat(value2);
				if(Math.isNaN(val1)) val1 = 1;
				if(Math.isNaN(val2)) val2 = 0;

				var newValue:Float = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed', 1) * val1;

				if(val2 <= 0)
				{
					songSpeed = newValue;
				}
				else
				{
					songSpeedTween = FlxTween.tween(this, {songSpeed: newValue}, val2 / playbackRate, {ease: FlxEase.linear, onComplete:
						function (twn:FlxTween)
						{
							songSpeedTween = null;
						}
					});
				}

			case 'Set Property':
				var killMe:Array<String> = value1.split('.');
				if(killMe.length > 1) {
					FunkinLua.setVarInArray(FunkinLua.getPropertyLoopThingWhatever(killMe, true, true), killMe[killMe.length-1], value2);
				} else {
					FunkinLua.setVarInArray(this, value1, value2);
				}
		}
		callOnLuas('onEvent', [eventName, value1, value2]);
	}

	var cameraTwn:FlxTween;
	function moveCameraSection():Void {
		var section = SONG.notes[curSection];
		if (section == null) return;

		if (gf != null && section.gfSection) {
			camFollow.set(gf.getMidpoint().x, gf.getMidpoint().y);
			camFollow.x += gf.cameraPosition[0] + girlfriendCameraOffset[0];
			camFollow.y += gf.cameraPosition[1] + girlfriendCameraOffset[1];

			if (canTweenCamZoom) tweenCamZoom(canTweenCamZoomGf);
			callOnLuas('onMoveCamera', ['gf']);
			return;
		}

		if (section.mustHitSection) {
			moveCamera(false);
			callOnLuas('onMoveCamera', ['boyfriend']);
		}
		else {
			moveCamera(true);
			callOnLuas('onMoveCamera', ['dad']);
		}
	}

	public function moveCamera(isDad:Bool) {
		if (isDad) {
			camFollow.set(dad.getMidpoint().x + 150, dad.getMidpoint().y - 100);
			camFollow.x += dad.cameraPosition[0] + opponentCameraOffset[0];
			camFollow.y += dad.cameraPosition[1] + opponentCameraOffset[1];
			if (canTweenCamZoom) tweenCamZoom(canTweenCamZoomDad);
		}
		else {
			camFollow.set(boyfriend.getMidpoint().x - 100, boyfriend.getMidpoint().y - 100);
			camFollow.x -= boyfriend.cameraPosition[0] - boyfriendCameraOffset[0];
			camFollow.y += boyfriend.cameraPosition[1] + boyfriendCameraOffset[1];
			if (canTweenCamZoom) tweenCamZoom(canTweenCamZoomBoyfriend);
		}
	}

	// deprecated lmfao
	public function tweenCamIn() {tweenCamZoom(1.3);}

	public function tweenCamZoom(zoom:Float = 1) {
		if (cameraTwn == null && camGame.zoom != zoom) {
			cameraTwn = FlxTween.tween(camGame, {zoom: zoom}, (Conductor.stepCrochet * 4 / 1000), {ease: FlxEase.elasticInOut, onComplete: function(_) {
				cameraTwn = null;
			}});
		}
	}

	function snapCamFollowToPos(x:Float, y:Float) {
		camFollow.set(x, y);
		camFollowPos.setPosition(x, y);
	}

	public function finishSong(?ignoreNoteOffset:Bool = false):Void {
		var finishCallback:Void->Void = endSong; //In case you want to change it in a specific song.

		updateTime = false;
		FlxG.sound.music.volume = 0;
		vocals.volume = 0;
		vocals.pause();
		if(ClientPrefs.noteOffset <= 0 || ignoreNoteOffset) {
			finishCallback();
		} else {
			finishTimer = new FlxTimer().start(ClientPrefs.noteOffset / 1000, function(tmr:FlxTimer) {
				finishCallback();
			});
		}
	}

	public var transitioning = false;
	public function endSong():Void
	{
		//Should kill you if you tried to cheat
		if(!startingSong) {
			notes.forEach(function(daNote:Note) {
				if(daNote.strumTime < songLength - Conductor.safeZoneOffset) {
					health -= 0.05 * healthLoss;
				}
			});
			for (daNote in unspawnNotes) {
				if(daNote.strumTime < songLength - Conductor.safeZoneOffset) {
					health -= 0.05 * healthLoss;
				}
			}

			if(doDeathCheck()) {
				return;
			}
		}

		timeBarBG.visible = false;
		timeBar.visible = false;
		timeTxt.visible = false;
		canPause = false;
		endingSong = true;
		camZooming = false;
		inCutscene = false;
		updateTime = false;

		deathCounter = 0;
		seenCutscene = false;
		restarted = false;

		#if ACHIEVEMENTS_ALLOWED
		if(achievementObj != null) {
			return;
		} else {
			var achieve:String = checkForAchievement(['week1_nomiss', 'week2_nomiss', 'week3_nomiss', 'week4_nomiss',
				'week5_nomiss', 'week6_nomiss', 'week7_nomiss', 'ur_bad',
				'ur_good', 'hype', 'two_keys', 'toastie', 'debugger']);

			if(achieve != null) {
				startAchievement(achieve);
				return;
			}
		}
		#end

		var ret:Dynamic = callOnLuas('onEndSong', [], false);
		if(ret != FunkinLua.Function_Stop && !transitioning) {
			if (SONG.validScore)
			{
				#if !switch
				var percent:Float = ratingPercent;
				if(Math.isNaN(percent)) percent = 0;
				Highscore.saveScore(SONG.song, songScore, storyDifficulty, percent);
				#end
			}
			playbackRate = 1;
			vocals.volume = 0;
			vocals.stop();

			if (chartingMode)
			{
				openChartEditor();
				return;
			}

			if (isStoryMode)
			{
				campaignScore += songScore;
				campaignMisses += songMisses;

				storyPlaylist.remove(storyPlaylist[0]);

				if (storyPlaylist.length <= 0)
				{
					WeekData.loadTheFirstEnabledMod();
					FlxG.sound.playMusic(Paths.music('freakyMenu'));

					cancelMusicFadeTween();
					if(FlxTransitionableState.skipNextTransIn) {
						CustomFadeTransition.nextCamera = null;
					}
					MusicBeatState.switchState(new StoryMenuState());

					// if ()
					if(!ClientPrefs.getGameplaySetting('practice', false) && !ClientPrefs.getGameplaySetting('botplay', false)) {
						StoryMenuState.weekCompleted.set(WeekData.weeksList[storyWeek], true);

						if (SONG.validScore)
						{
							Highscore.saveWeekScore(WeekData.getWeekFileName(), campaignScore, storyDifficulty);
						}

						FlxG.save.data.weekCompleted = StoryMenuState.weekCompleted;
						FlxG.save.flush();
					}
					changedDifficulty = false;
				}
				else
				{
					var difficulty:String = CoolUtil.getDifficultyFilePath();

					trace('LOADING NEXT SONG');
					trace(Paths.formatToSongPath(PlayState.storyPlaylist[0]) + difficulty);

					if (lightShutOffEnd) {
						var blackShit:FlxSprite = new FlxSprite().makeGraphic(1, 1, lightShutOffColor);
						blackShit.setGraphicSize(16384);
						blackShit.scrollFactor.set();
						blackShit.updateHitbox();
						blackShit.screenCenter();
						add(blackShit);

						camHUD.visible = false;
						FlxG.sound.play(Paths.sound('Lights_Shut_off'));
					}

					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;

					prevCamFollow = camFollow;
					prevCamFollowPos = camFollowPos;

					PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0] + difficulty, PlayState.storyPlaylist[0]);
					FlxG.sound.music.stop();

					if (lightShutOffEnd) {
						new FlxTimer().start(2, function(tmr:FlxTimer) {
							cancelMusicFadeTween();
							LoadingState.loadAndSwitchState(new PlayState());
						});
					}
					else {
						cancelMusicFadeTween();
						LoadingState.loadAndSwitchState(new PlayState());
					}
				}
			}
			else
			{
				trace('WENT BACK TO FREEPLAY??');
				WeekData.loadTheFirstEnabledMod();
				cancelMusicFadeTween();
				if(FlxTransitionableState.skipNextTransIn) {
					CustomFadeTransition.nextCamera = null;
				}
				MusicBeatState.switchState(new FreeplayState());
				FlxG.sound.playMusic(Paths.music('freakyMenu'));
				changedDifficulty = false;
			}
			transitioning = true;
		}
	}

	#if ACHIEVEMENTS_ALLOWED
	var achievementObj:AchievementObject = null;
	function startAchievement(achieve:String) {
		achievementObj = new AchievementObject(achieve, camOther);
		achievementObj.onFinish = achievementEnd;
		add(achievementObj);
		trace('Giving achievement ' + achieve);
	}
	function achievementEnd():Void
	{
		achievementObj = null;
		if(endingSong && !inCutscene) {
			endSong();
		}
	}
	#end

	public function KillNotes() {
		while(notes.length > 0) {
			var daNote:Note = notes.members[0];
			daNote.active = false;
			daNote.visible = false;

			daNote.kill();
			notes.remove(daNote, true);
			daNote.destroy();
		}
		unspawnNotes = [];
		eventNotes = [];
	}

	public var totalPlayed:Float = 0;
	public var totalNotesHit:Float = 0;

	public var showCombo:Bool = false;
	public var showComboNum:Bool = true;
	public var showRating:Bool = true;

	public static var lastRatingSpr:RatingSpr;
	public static var lastRating:FlxSprite;
	public static var lastCombo:FlxSprite;
	public static var lastScore:Array<FlxSprite> = [];

	private function cachePopUpScore():Void
	{
		var p1:String = '';
		var p2:String = '';
		if (isPixelStage) {
			p1 = 'pixelUI/';
			p2 = '-pixel';
		}

		Paths.image(p1 + 'sick' + p2, 'shared');
		Paths.image(p1 + 'good' + p2, 'shared');
		Paths.image(p1 + 'bad' + p2, 'shared');
		Paths.image(p1 + 'shit' + p2, 'shared');
		Paths.image(p1 + 'combo' + p2, 'shared');

		for (i in 0...10) Paths.image(p1 + 'num$i' + p2);
		Paths.image(p1 + 'numnegative' + p2);
	}

	// deprecated lmfao
	public function popUpScore(note:Note):Void
	{
		if (note == null) return;

		var noteDiff:Float = Math.abs(note.strumTime - Conductor.songPosition + ClientPrefs.ratingOffset) / getActualPlaybackRate();
		var daRating:Rating = Conductor.judgeNote(note, noteDiff);

		note.ratingMod = daRating.ratingMod;
		note.rating = daRating.name;

		if (!note.ratingDisabled) daRating.increase();
		totalNotesHit += daRating.ratingMod;

		if (daRating.noteSplash && !note.noteSplashDisabled)
			spawnNoteSplashOnNote(note);

		if (!practiceMode && !cpuControlled) {
			songScore += daRating.score;
			if (!note.ratingDisabled) {
				songHits++;
				totalPlayed++;
				RecalculateRating(false);
			}
		}

		return popUpRating(noteDiff, daRating);
	}

	private function popUpRating(diff:Float, ?rating:Rating):Void
	{
		if (!ClientPrefs.comboStacking && lastRatingSpr != null) lastRatingSpr.destroy();
		var ratingSpr:RatingSpr = new RatingSpr(this, {
			showRating: showRating,
			showCombo: showCombo,
			showComboNum: showComboNum,
			isPixel: isPixelStage,
			speedRate: playbackRate,

			rating: rating,
			diff: diff,
			combo: combo
		}, camHUD, members.indexOf(strumLineNotes));

		lastRatingSpr = ratingSpr;
		lastRating = ratingSpr.rating;
		lastCombo = ratingSpr.combo;
		if (lastScore == null) lastScore = [];

		lastScore.resize(0);
		for (v in ratingSpr.comboNums) lastScore.push(v);
	}

	private function initializeKeyboard() {
		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
	}

	private function deinitializeKeyboard() {
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
	}

	private function initializeGamepads() {
		#if FLX_GAMEPAD
		#if FLX_JOYSTICK_API
		FlxG.stage.addEventListener(JoystickEvent.BUTTON_DOWN, onButtonPress);
		FlxG.stage.addEventListener(JoystickEvent.BUTTON_UP, onButtonRelease);
		#elseif FLX_GAMEINPUT_API
		FlxG.gamepads.deviceConnected.add(gamepadConnected);
		FlxG.gamepads.deviceDisconnected.add(gamepadDisconnected);

		@:privateAccess
		for (gamepad in FlxG.gamepads._gamepads) {
			if (gamepad != null) gamepadConnected(gamepad);
		}
		#end
		#end
	}

	private function deinitializeGamepads() {
		#if FLX_GAMEPAD
		#if FLX_JOYSTICK_API
		FlxG.stage.removeEventListener(JoystickEvent.BUTTON_DOWN, onButtonPress);
		FlxG.stage.removeEventListener(JoystickEvent.BUTTON_UP, onButtonRelease);
		#elseif FLX_GAMEINPUT_API
		FlxG.gamepads.deviceConnected.remove(gamepadConnected);
		FlxG.gamepads.deviceDisconnected.remove(gamepadDisconnected);

		for (gamepad in gamepads) {
			gamepadDisconnected(gamepad);
		}
		#end
		#end
	}

	private function inputPress(key:Int) {
		fillKeysPressed();

		keysPressed[key] = true;
		keysUsed[key] = true;

		//more accurate hit time for the ratings
		if (!boyfriend.stunned && generatedMusic && !endingSong) {
			var lastTime:Float = Conductor.songPosition;
			if (FlxG.sound.music != null && FlxG.sound.music.playing && !startingSong)
				Conductor.songPosition = FlxG.sound.music.time;

			var sortedNotesList:Array<Note> = [];
			var canMiss:Bool = !ClientPrefs.ghostTapping;
			var notesStopped:Bool = false;

			notes.forEachAlive(function(daNote:Note) {
				if (!strumsBlocked[daNote.noteData] && daNote.mustPress && !daNote.blockHit && !daNote.tooLate) {
					if (!daNote.isSustainNote && !daNote.wasGoodHit) {
						if (!daNote.canBeHit && daNote.checkDiff(Conductor.songPosition)) daNote.update(0);
						if (daNote.canBeHit) {
							if (daNote.noteData == key) sortedNotesList.push(daNote);
							canMiss = true;
						}
					}
					else if (daNote.isSustainNote && daNote.noteData == key && ((daNote.wasGoodHit || daNote.prevNote.wasGoodHit) &&
					(daNote.parent != null && !daNote.parent.hasMissed && daNote.parent.wasGoodHit)))
						sortedNotesList.push(daNote);
				}
			});

			sortedNotesList.sort(sortHitNotes);
			var pressNotes:Array<Note> = [];

			if (sortedNotesList.length > 0) {
				for (epicNote in sortedNotesList) {
					for (doubleNote in pressNotes) {
						if (Math.abs(doubleNote.strumTime - epicNote.strumTime) > 3)
							notesStopped = true;
					}

					// eee jack detection before was not super good
					if (!notesStopped) {
						if (epicNote.isSustainNote) {
							StrumPlayAnim(false, key);
							continue;
						}
						pressNotes.push(epicNote);
						goodNoteHit(epicNote);
					}
				}
			}
			else {
				callOnLuas('onGhostTap', [key]);
				if (canMiss) noteMissPress(key);
			}

			//more accurate hit time for the ratings? part 2 (Now that the calculations are done, go back to the time it was before for not causing a note stutter)
			Conductor.songPosition = lastTime;
		}

		if (!strumsBlocked[key]) {
			var spr:StrumNote = playerStrums.members[key];
			if (spr != null && spr.animation.curAnim.name != 'confirm') {
				spr.playAnim('pressed');
				spr.resetAnim = 0;
			}
		}
		callOnLuas('onKeyPress', [key]);
		// trace('Pressed: ' + controlArray[key]);
	}

	function sortHitNotes(a:Note, b:Note):Int {
		if (a.lowPriority && !b.lowPriority)
			return 1;
		else if (!a.lowPriority && b.lowPriority)
			return -1;

		return FlxSort.byValues(FlxSort.ASCENDING, a.strumTime, b.strumTime);
	}

	private function inputRelease(key:Int) {
		if (!keysPressed[key]) return;
		fillKeysPressed();

		keysPressed[key] = false;

		var spr:StrumNote = playerStrums.members[key];
		if (spr != null) {
			spr.playAnim('static');
			spr.resetAnim = 0;
		}
		callOnLuas('onKeyRelease', [key]);
	}

	private function onKeyPress(event:KeyboardEvent):Void {
		if (cpuControlled || !startedCountdown || paused) return;

		// keeping the controllerMode statement for backward compatibility for luas
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(eventKey);
		if (key >= 0 && (ClientPrefs.controllerMode || FlxG.keys.checkStatus(eventKey, JUST_PRESSED)))
			inputPress(key);
	}

	private function onKeyRelease(event:KeyboardEvent):Void {
		if (cpuControlled || !startedCountdown || paused) return;

		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(eventKey);
		if (key >= 0)
			inputRelease(key);
	}

	#if FLX_GAMEPAD

	#if FLX_JOYSTICK_API
	private function onButtonPress(event:JoystickEvent) {
		
	}

	private function onButtonRelease(event:JoystickEvent) {
		
	}
	#elseif FLX_GAMEINPUT_API
	private var gamepads:Array<FlxGamepad> = [];
	private function gamepadConnected(gamepad:FlxGamepad) {
		if (gamepads.contains(gamepad)) return;
		gamepads.push(gamepad);
		
	}

	private function gamepadDisconnected(gamepad:FlxGamepad) {
		if (!gamepads.contains(gamepad)) return;
		gamepads.remove(gamepad);
	}
	#end

	#end

	private function fillKeysPressed() {
		var keybinds:Int = keysArray.length;
		if (strumsBlocked != null) while (strumsBlocked.length < keybinds) strumsBlocked.push(false);
		if (keysPressed != null) while (keysPressed.length < keybinds) keysPressed.push(false);
		if (keysUsed != null) while (keysUsed.length < keybinds) keysUsed.push(false);
	}

	private function getKeyFromEvent(key:FlxKey):Int {
		if (key != NONE) {
			for (i in 0...keysArray.length) if (keysArray[i].contains(key)) return i;
		}
		return -1;
	}

	// kinda deprecated?
	private function keyShit():Void {
		// Hold notes
		if (startedCountdown && !boyfriend.stunned) {
			notes.forEachAlive(function(daNote:Note) {
				if (strumsBlocked[daNote.noteData] != true && keysPressed[daNote.noteData] && daNote.isSustainNote && (daNote.parent == null
				|| daNote.parent.wasGoodHit) && daNote.canBeHit && daNote.mustPress && !daNote.tooLate && !daNote.wasGoodHit && !daNote.blockHit) {
					goodNoteHit(daNote);
				}
			});
		}
	}

	private function processInputs(elapsed:Float):Void {
		if (startedCountdown) {	
			notes.forEachAlive(function(daNote:Note) {
				if (!daNote.mustPress && !daNote.hitByOpponent && !daNote.ignoreNote && daNote.checkHit(Conductor.songPosition))
					opponentNoteHit(daNote);

				if (cpuControlled && !daNote.blockHit && daNote.mustPress && daNote.canBeHit && (daNote.isSustainNote
					? (daNote.parent == null || daNote.parent.wasGoodHit) : daNote.checkHit(Conductor.songPosition)))
					goodNoteHit(daNote);

				// Hold notes
				if (cpuControlled || boyfriend.stunned) return;
				if (daNote.isSustainNote && strumsBlocked[daNote.noteData] != true && keysPressed[daNote.noteData] && (daNote.parent == null
				|| daNote.parent.wasGoodHit) && daNote.canBeHit && daNote.mustPress && !daNote.tooLate && !daNote.wasGoodHit && !daNote.blockHit) {
					goodNoteHit(daNote);
				}
			});

			#if ACHIEVEMENTS_ALLOWED
			if (keysPressed.contains(true) && !endingSong) {
				var achieve:String = checkForAchievement(['oversinging']);
				if (achieve != null) startAchievement(achieve);
			}
			#end
		}
	}

	public function getControl(key:String) {
		return Reflect.getProperty(controls, key);
	}

	private function parseKeys(?suffix:String = ''):Array<Bool>
	{
		var ret:Array<Bool> = [];
		for (i in 0...controlArray.length) {
			ret[i] = getControl(controlArray[i] + suffix);
		}
		return ret;
	}

	//You didn't hit the key and let it go offscreen, also used by Hurt Notes
	function noteMiss(daNote:Note):Void
	{
		if (daNote.hasMissed) return;
		daNote.hasMissed = true;
		daNote.active = false;

		notes.forEachAlive(function(note:Note) {
			if (daNote != note && daNote.mustPress && daNote.noteData == note.noteData && daNote.isSustainNote == note.isSustainNote && Math.abs(daNote.strumTime - note.strumTime) < 1) {
				note.kill();
				notes.remove(note, true);
				note.destroy();
			}
		});

		if (!practiceMode) songScore -= 10;
		vocals.volume = 0;

		if (ClientPrefs.missSustainsOnce && daNote.isSustainNote) {
			if (ClientPrefs.scoresOnSustains) totalPlayed += sustainScoreMult;

			var parent:Note = daNote.parent;
			if (parent != null && !parent.hasMissed) {
				parent.visible = false;
				parent.tooLate = true;
				noteMiss(parent);

				notes.remove(parent, true);
				parent.kill();
				parent.destroy();
			}
			return RecalculateRating(true);
		}
		if (ClientPrefs.scoresOnSustains) totalPlayed += sustainScoreMult;
		else totalPlayed++;

		if (combo > 10 && gf != null && gf.animOffsets.exists('sad'))
			gf.playAnim('sad');

		health -= daNote.missHealth * healthLoss;
		songMisses++;
		combo = 0;

		if (instakillOnMiss) doDeathCheck(true);
		RecalculateRating(true);

		var leData:Int = Std.int(Math.abs(daNote.noteData));
		var char:Character = daNote.gfNote ? gf : boyfriend;
		if (char != null && !daNote.noMissAnimation && char.hasMissAnimations)
			char.playAnim(singAnimations[leData] + 'miss' + daNote.animSuffix, true);

		callOnLuas('noteMiss', [notes.members.indexOf(daNote), leData, daNote.noteType, daNote.isSustainNote]);
	}

	//You pressed a key when there was no notes to press for this key
	function noteMissPress(direction:Int = 1):Void
	{
		if (boyfriend.stunned || ClientPrefs.ghostTapping) return;

		if (combo > 5 && gf != null && gf.animOffsets.exists('sad'))
			gf.playAnim('sad');

		if (!practiceMode) songScore -= 10;
		if (!endingSong) songMisses++;
		health -= 0.05 * healthLoss;
		vocals.volume = 0;
		totalPlayed++;
		combo = 0;

		if (instakillOnMiss) doDeathCheck(true);
		RecalculateRating(true);

		FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
		/* idk whats this for
		boyfriend.stunned = true;

		// get stunned for 1/60 of a second, makes you able to
		new FlxTimer().start(1 / 60, function(tmr:FlxTimer)
		{
			boyfriend.stunned = false;
		});
		*/

		if (boyfriend.hasMissAnimations)
			boyfriend.playAnim(singAnimations[Std.int(Math.abs(direction))] + 'miss', true);

		callOnLuas('noteMissPress', [direction]);
	}

	function opponentNoteHit(note:Note):Void
	{
		if (!dontZoomCam) camZooming = true;
		if (SONG.needsVoices) vocals.volume = 1;

		var isSus:Bool = note.isSustainNote; //GET OUT OF MY HEAD, GET OUT OF MY HEAD, GET OUT OF MY HEAD
		var leData:Int = Math.floor(Math.abs(note.noteData));
		var leType:String = note.noteType;

		note.hitByOpponent = true;

		if (leType == 'Hey!' && dad.animOffsets.exists('hey')) {
			dad.playAnim('hey', true);
			dad.specialAnim = true;
			dad.heyTimer = 0.6;
		}
		else if (!note.noAnimation) {
			var altAnim:String = note.animSuffix;
			if (SONG.notes[curSection] != null && SONG.notes[curSection].altAnim && !SONG.notes[curSection].gfSection)
				altAnim = '-alt';

			var char:Character = note.gfNote ? gf : dad;
			var animToPlay:String = singAnimations[leData] + altAnim;
			if (char != null) {
				char.playAnim(animToPlay, true);
				char.holdTimer = 0;
			}
		}

		var time:Float = 0.15;
		if (isSus && !note.animation.curAnim.name.endsWith('end'))
			time += 0.15;

		StrumPlayAnim(true, leData, time);

		callOnLuas('opponentNoteHit', [notes.members.indexOf(note), leData, leType, isSus]);

		if (!isSus) {
			note.kill();
			notes.remove(note, true);
			note.destroy();
		}
	}

	function goodNoteHit(note:Note):Void
	{
		if (note.wasGoodHit || (cpuControlled && (note.ignoreNote || note.hitCausesMiss))) return;

		if (ClientPrefs.hitsoundVolume > 0 && !note.hitsoundDisabled)
			FlxG.sound.play(Paths.sound('hitsound'), ClientPrefs.hitsoundVolume);

		var isSus:Bool = note.isSustainNote; //GET OUT OF MY HEAD, GET OUT OF MY HEAD, GET OUT OF MY HEAD
		var leData:Int = Math.floor(Math.abs(note.noteData));
		var leType:String = note.noteType;

		if (note.hitCausesMiss) {
			noteMiss(note);
			if (!note.noteSplashDisabled && !isSus)
				spawnNoteSplashOnNote(note);

			if (!note.noMissAnimation) {
				switch(leType) {
					case 'Hurt Note': //Hurt note
						if (boyfriend.animation.getByName('hurt') != null) {
							boyfriend.playAnim('hurt', true);
							boyfriend.specialAnim = true;
						}
				}
			}

			note.wasGoodHit = true;
			if (!isSus) {
				note.kill();
				notes.remove(note, true);
				note.destroy();
			}
			return;
		}

		if (!dontZoomCam) camZooming = true;
		if (SONG.needsVoices) vocals.volume = 1;
		health += note.hitHealth * healthGain;

		// I KNOW THIS LOOKS STUPID BUT TRUST ME, ORDER MATTERS FOR BACKWARD COMPATIBILITY -raltyro
		var noteDiff:Float = isSus ? 0 : Math.abs(note.strumTime - Conductor.songPosition + ClientPrefs.ratingOffset) / getActualPlaybackRate();
		var rating:Rating = Conductor.judgeNote(note, noteDiff);
		var canAddScores:Bool = !isSus || ClientPrefs.scoresOnSustains;
		var scoreGain:Float = isSus ? sustainScoreMult : 1;

		note.ratingMod = rating.ratingMod;
		note.rating = rating.name;
		note.wasGoodHit = true;

		if (canAddScores) totalNotesHit += rating.ratingMod * (isSus ? .5 : 1);
		if (!isSus) {
			combo++;
			//if (combo > 9999) combo = 9999;

			if (!note.ratingDisabled) rating.increase();
			if (rating.noteSplash && !note.noteSplashDisabled)
				spawnNoteSplashOnNote(note);
		}

		if (canAddScores && !practiceMode && !cpuControlled) {
			songScore += Math.round(rating.score * scoreGain);
			if (!note.ratingDisabled) {
				if (!isSus) songHits++;
				totalPlayed += (isSus ? .5 : 1);
				RecalculateRating(false);
			}
		}

		if (!isSus) popUpRating(noteDiff, rating);

		if (!note.noAnimation) {
			if (leType == 'Hey!') {
				if (boyfriend.animOffsets.exists('hey')) {
					boyfriend.playAnim('hey', true);
					boyfriend.specialAnim = true;
					boyfriend.heyTimer = 0.6;
				}

				if (gf != null && gf.animOffsets.exists('cheer')) {
					gf.playAnim('cheer', true);
					gf.specialAnim = true;
					gf.heyTimer = 0.6;
				}
			}
			else {
				var animToPlay:String = singAnimations[leData];

				if (note.gfNote) {
					if (gf != null) {
						gf.playAnim(animToPlay + note.animSuffix, true);
						gf.holdTimer = 0;
					}
				}
				else {
					boyfriend.playAnim(animToPlay + note.animSuffix, true);
					boyfriend.holdTimer = 0;
				}
			}
		}

		var time:Float = 0;
		if (cpuControlled) {
			time = 0.15;
			if (isSus && !note.animation.curAnim.name.endsWith('end'))
				time += 0.15;
		}
		StrumPlayAnim(false, leData, time);

		callOnLuas('goodNoteHit', [notes.members.indexOf(note), leData, leType, isSus]);

		if (!isSus) {
			note.kill();
			notes.remove(note, true);
			note.destroy();
		}
	}

	public function spawnNoteSplashOnNote(note:Note) {
		if(ClientPrefs.noteSplashes && note != null) {
			var strum:StrumNote = playerStrums.members[note.noteData];
			if(strum != null) {
				spawnNoteSplash(strum.x, strum.y, note.noteData, note);
			}
		}
	}

	public function spawnNoteSplash(x:Float, y:Float, data:Int, ?note:Note = null) {
		var skin:String = 'noteSplashes';
		if(PlayState.SONG.splashSkin != null && PlayState.SONG.splashSkin.length > 0) skin = PlayState.SONG.splashSkin;

		var hue:Float = 0;
		var sat:Float = 0;
		var brt:Float = 0;
		if (data > -1 && data < ClientPrefs.arrowHSV.length)
		{
			hue = ClientPrefs.arrowHSV[data][0] / 360;
			sat = ClientPrefs.arrowHSV[data][1] / 100;
			brt = ClientPrefs.arrowHSV[data][2] / 100;
			if(note != null) {
				skin = note.noteSplashTexture;
				hue = note.noteSplashHue;
				sat = note.noteSplashSat;
				brt = note.noteSplashBrt;
			}
		}

		var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
		splash.setupNoteSplash(x, y, data, skin, hue, sat, brt);
		grpNoteSplashes.add(splash);
	}

	// psike
	public function charactersDance():Void {
		var chars = [gf, boyfriend, dad];
		for (char in chars) {
			if (char == null) continue;
			var speed = (gf != null && char == gf) ? gfSpeed : 1;
			var curAnim = char.animation.curAnim;
			if ((curAnim == null || !curAnim.name.startsWith('sing')) && !char.stunned
			&& curBeat % Math.round(speed * char.danceEveryNumBeats) == 0)
				char.dance();
		}
	}

	var fastCarCanDrive:Bool = true;

	function resetFastCar():Void
	{
		fastCar.x = -12600;
		fastCar.y = FlxG.random.int(140, 250);
		fastCar.velocity.x = 0;
		fastCarCanDrive = true;
	}

	var carTimer:FlxTimer;
	function fastCarDrive()
	{
		//trace('Car drive');
		FlxG.sound.play(Paths.soundRandom('carPass', 0, 1), 0.7);

		fastCar.velocity.x = (FlxG.random.int(170, 220) / FlxG.elapsed) * 3;
		fastCarCanDrive = false;
		carTimer = new FlxTimer().start(2, function(tmr:FlxTimer)
		{
			resetFastCar();
			carTimer = null;
		});
	}

	var trainMoving:Bool = false;
	var trainFrameTiming:Float = 0;

	var trainCars:Int = 8;
	var trainFinishing:Bool = false;
	var trainCooldown:Int = 0;

	function trainStart():Void
	{
		trainMoving = true;
		if (!trainSound.playing)
			trainSound.play(true);
	}

	var startedMoving:Bool = false;

	function updateTrainPos():Void
	{
		if (trainSound.time >= 4700)
		{
			startedMoving = true;
			if (gf != null)
			{
				gf.playAnim('hairBlow');
				gf.specialAnim = true;
			}
		}

		if (startedMoving)
		{
			phillyTrain.x -= 400;

			if (phillyTrain.x < -2000 && !trainFinishing)
			{
				phillyTrain.x = -1150;
				trainCars -= 1;

				if (trainCars <= 0)
					trainFinishing = true;
			}

			if (phillyTrain.x < -4000 && trainFinishing)
				trainReset();
		}
	}

	function trainReset():Void
	{
		if(gf != null)
		{
			gf.danced = false; //Sets head to the correct position once the animation ends
			gf.playAnim('hairFall');
			gf.specialAnim = true;
		}
		phillyTrain.x = FlxG.width + 200;
		trainMoving = false;
		// trainSound.stop();
		// trainSound.time = 0;
		trainCars = 8;
		trainFinishing = false;
		startedMoving = false;
	}

	function lightningStrikeShit():Void
	{
		FlxG.sound.play(Paths.soundRandom('thunder_', 1, 2));
		if(!ClientPrefs.lowQuality) halloweenBG.animation.play('halloweem bg lightning strike');

		lightningStrikeBeat = curBeat;
		lightningOffset = FlxG.random.int(8, 24);

		if(boyfriend.animOffsets.exists('scared')) {
			boyfriend.playAnim('scared', true);
		}

		if(gf != null && gf.animOffsets.exists('scared')) {
			gf.playAnim('scared', true);
		}

		if(ClientPrefs.camZooms) {
			FlxG.camera.zoom += 0.015;
			camHUD.zoom += 0.03;

			if(!camZooming) { //Just a way for preventing it to be permanently zoomed until Skid & Pump hits a note
				FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom}, 0.5);
				FlxTween.tween(camHUD, {zoom: 1}, 0.5);
			}
		}

		if(ClientPrefs.flashing) {
			halloweenWhite.alpha = 0.4;
			FlxTween.tween(halloweenWhite, {alpha: 0.5}, 0.075);
			FlxTween.tween(halloweenWhite, {alpha: 0}, 0.25, {startDelay: 0.15});
		}
	}

	function killHenchmen():Void
	{
		if(!ClientPrefs.lowQuality && ClientPrefs.violence && curStage == 'limo') {
			if(limoKillingState < 1) {
				limoMetalPole.x = -400;
				limoMetalPole.visible = true;
				limoLight.visible = true;
				limoCorpse.visible = false;
				limoCorpseTwo.visible = false;
				limoKillingState = 1;

				#if ACHIEVEMENTS_ALLOWED
				Achievements.henchmenDeath++;
				FlxG.save.data.henchmenDeath = Achievements.henchmenDeath;
				var achieve:String = checkForAchievement(['roadkill_enthusiast']);
				if (achieve != null) {
					startAchievement(achieve);
				} else {
					FlxG.save.flush();
				}
				FlxG.log.add('Deaths: ' + Achievements.henchmenDeath);
				#end
			}
		}
	}

	function resetLimoKill():Void
	{
		if(curStage == 'limo') {
			limoMetalPole.x = -500;
			limoMetalPole.visible = false;
			limoLight.x = -500;
			limoLight.visible = false;
			limoCorpse.x = -500;
			limoCorpse.visible = false;
			limoCorpseTwo.x = -500;
			limoCorpseTwo.visible = false;
		}
	}

	var tankX:Float = 400;
	var tankSpeed:Float = FlxG.random.float(5, 7);
	var tankAngle:Float = FlxG.random.int(-90, 45);

	function moveTank(?elapsed:Float = 0):Void
	{
		if(!inCutscene)
		{
			tankAngle += elapsed * tankSpeed;
			tankGround.angle = tankAngle - 90 + 15;
			tankGround.x = tankX + 1500 * Math.cos(Math.PI / 180 * (1 * tankAngle + 180));
			tankGround.y = 1300 + 1100 * Math.sin(Math.PI / 180 * (1 * tankAngle + 180));
		}
	}

	override function destroy() {
		deinitializeKeyboard();
		deinitializeGamepads();

		cleanupLuas(true);
		#if hscript
		FunkinLua.hscript.destroy();
		FunkinLua.hscript = null;
		#end

		@:privateAccess
		if (Std.isOfType(FlxG.game._requestedState, PlayState)) {
			if (FlxG.sound.music != null) FlxG.sound.music.destroy();
		}
		else {
			Paths.clearStoredMemory();
			if (FlxG.sound.music != null) {
				FlxG.sound.music.onComplete = null;
				FlxG.sound.music.pitch = 1;
			}
		}

		FlxAnimationController.globalSpeed = 1;

		super.destroy();
	}

	public static function cancelMusicFadeTween() {
		if(FlxG.sound.music.fadeTween != null) {
			FlxG.sound.music.fadeTween.cancel();
		}
		FlxG.sound.music.fadeTween = null;
	}

	var lastStepHit:Int = -1;
	override function stepHit() {
		setOnLuas('curDecStep', curDecStep);
		setOnLuas('curDecBeat', curDecBeat);
		super.stepHit();

		if (!paused && !startingSong) {
			var time:Float = FlxG.sound.music.time;
			var resync:Bool = vocals.loaded && Math.abs(vocals.time - time) > 12;
			if (Math.abs(time - (Conductor.songPosition - Conductor.offset)) > 16 || resync)
				resyncVocals(resync);
		}

		if (curStep == lastStepHit) return;

		lastStepHit = curStep;
		setOnLuas('curStep', curStep);
		callOnLuas('onStepHit');
	}

	var lightningStrikeBeat:Int = 0;
	var lightningOffset:Int = 8;

	var lastBeatHit:Int = -1;
	override function beatHit() {
		super.beatHit();

		if (curBeat < lastBeatHit) {
			//trace('BEAT HIT: ' + curBeat + ', LAST HIT: ' + lastBeatHit);
			return;
		}

		//if (generatedMusic)
		//	notes.sort(FlxSort.byY, ClientPrefs.downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);

		charactersDance();

		iconP1.scale.set(1.2, 1.2);
		iconP2.scale.set(1.2, 1.2);
		iconP1.updateHitbox();
		iconP2.updateHitbox();

		switch(curStage) {
			case 'spooky': {
				if (FlxG.random.bool(10) && curBeat > lightningStrikeBeat + lightningOffset)
					lightningStrikeShit();
			}
			case 'tank': {
				if (!ClientPrefs.lowQuality) tankWatchtower.dance();
				foregroundSprites.forEach(function(spr:BGSprite) {
					spr.dance();
				});
			}
			case 'school': {
				if (bgGirls != null) bgGirls.dance();
			}
			case 'mall': {
				if (upperBoppers != null)
					upperBoppers.dance(true);

				if (heyTimer <= 0) bottomBoppers.dance(true);
				santa.dance(true);
			}
			case 'limo': {
				if (!ClientPrefs.lowQuality) {
					grpLimoDancers.forEach(function(dancer:BackgroundDancer) {
						dancer.dance();
					});
				}

				if (FlxG.random.bool(10) && fastCarCanDrive)
					fastCarDrive();
			}
			case "philly": {
				if (!trainMoving)
					trainCooldown += 1;

				if (curBeat % 4 == 0) {
					curLight = FlxG.random.int(0, phillyLightsColors.length - 1, [curLight]);
					phillyWindow.color = phillyLightsColors[curLight];
					phillyWindow.alpha = 1;
				}

				if (curBeat % 8 == 4 && FlxG.random.bool(30) && !trainMoving && trainCooldown > 8) {
					trainCooldown = FlxG.random.int(-4, 0);
					trainStart();
				}
			}
		}

		lastBeatHit = curBeat;

		setOnLuas('curBeat', curBeat);
		callOnLuas('onBeatHit');
	}

	override function sectionHit() {
		super.sectionHit();

		if (!startingSong && generatedMusic) changeDiscordPresence();
		if (SONG.notes[curSection] != null) {
			if (generatedMusic && !endingSong && !isCameraOnForcedPos)
				moveCameraSection();

			if (ClientPrefs.camZooms && camZooming && FlxG.camera.zoom < 1.35) {
				FlxG.camera.zoom += 0.015 * camZoomingMult;
				camHUD.zoom += 0.03 * camZoomingMult;
			}

			if (SONG.notes[curSection].changeBPM) {
				Conductor.changeBPM(SONG.notes[curSection].bpm);

				setOnLuas('curBpm', Conductor.bpm);
				setOnLuas('crochet', Conductor.crochet);
				setOnLuas('stepCrochet', Conductor.stepCrochet);
			}

			setOnLuas('mustHitSection', SONG.notes[curSection].mustHitSection);
			setOnLuas('altAnim', SONG.notes[curSection].altAnim);
			setOnLuas('gfSection', SONG.notes[curSection].gfSection);
		}
		
		setOnLuas('curSection', curSection);
		callOnLuas('onSectionHit');
	}

	public var presenceChangedByLua:Bool = false;
	public function changeDiscordPresence(?extraDetails:String, paused:Bool = false, force:Bool = false):Void {
		#if desktop
		if ((presenceChangedByLua && !force) || transitioning) return;
		var showTime:Bool = !paused && !startingSong && !isDead && generatedMusic;
		var scoreDetail:String = '[${Highscore.floorDecimal(ratingPercent * 100, 2)}% - ${ratingFC} | Misses: ${songMisses}]';
		DiscordClient.changePresence(
			(extraDetails != null ? '${extraDetails} - ' : '') + (paused ? detailsPausedText : detailsText),
			'${SONG.song} (${storyDifficultyText})' + ((!startingSong && totalPlayed > 0) ? ' $scoreDetail' : ''),
			iconP2 != null ? iconP2.getCharacter() : '',
			showTime,
			!showTime ? 0 : Math.max(songLength - Conductor.songPosition - ClientPrefs.noteOffset, 0)
		);
		#end
	}

	public function isLuaRunning(luaFile:String):Bool {
		#if LUA_ALLOWED
		luaFile = FunkinLua.format(luaFile);

		for (luaInstance in PlayState.instance.luaArray) {
			if (luaInstance.globalScriptName == luaFile && !luaInstance.closed)
				return true;
		}
		#end
		return false;
	}

	public function executeLua(luaFile:String, onlyCheckMods:Bool = false, restrict:Bool = false):FunkinLua {
		#if LUA_ALLOWED
		luaFile = FunkinLua.format(luaFile);

		#if MODS_ALLOWED
		var mod = restrict ? Paths.mods(luaFile) : Paths.modFolders(luaFile);
		if (FileSystem.exists(mod))
			return FunkinLua.execute(mod);
		else
		#end if (!onlyCheckMods && #if sys FileSystem.exists #else OpenFlAssets.exists #end(Paths.getPreloadPath(luaFile)))
			return FunkinLua.execute(Paths.getPreloadPath(luaFile));
		#end
		return null;
	}

	public function executeLuas(folder:String, onlyCheckMods:Bool = false):Array<FunkinLua> {
		#if (LUA_ALLOWED && sys)
		folder = folder.toLowerCase();
		folder = folder.endsWith('/') || folder.endsWith('\\') ? folder : '${folder}/';

		var foldersToCheck:Array<String> = [];
		var filesPushed:Array<String> = [];
		var luas:Array<FunkinLua> = [];
		if (!onlyCheckMods) foldersToCheck.push(Paths.getPreloadPath(folder));

		#if MODS_ALLOWED
		foldersToCheck.insert(0, Paths.mods(folder));
		if (Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods('${Paths.currentModDirectory}/$folder'));

		for (mod in Paths.getGlobalMods())
			foldersToCheck.insert(0, Paths.mods('${mod}/$folder'));
		#end

		for (folder in foldersToCheck) {
			if (FileSystem.exists(folder)) {
				for (file in FileSystem.readDirectory(folder)) {
					if (!file.endsWith('.lua') || filesPushed.contains(file)) continue;
					luas.push(FunkinLua.execute(folder + file));
					filesPushed.push(file);
				}
			}
		}

		return luas;
		#else
		return [];
		#end
	}

	public function callOnLuas(event:String, ?args:Array<Any>, ignoreStops = true, ?exclusions:Array<String>):Dynamic {
		var returnVal:Dynamic = FunkinLua.Function_Continue;
		#if LUA_ALLOWED
		for (script in luaArray) {
			if (exclusions != null && (exclusions.contains(script.globalScriptName) || exclusions.contains(script.scriptName)))
				continue;

			var ret:Dynamic = script.call(event, args);
			if(ret == FunkinLua.Function_StopLua && !ignoreStops)
				break;
			
			// had to do this because there is a bug in haxe where Stop != Continue doesnt work
			var bool:Bool = ret == FunkinLua.Function_Continue;
			if(!bool && ret != 0) returnVal = cast ret;
		}
		#end
		return returnVal;
	}

	public function setOnLuas(key:String, val:Any) {
		#if LUA_ALLOWED
		FunkinLua.globals.set(key, val);
		for (l in luaArray) l.set(key, val);
		#end
	}

	public function cleanupLuas(destroy:Bool = false) {
		var i:Int = luaArray.length;
		while (--i >= 0) {
			if (destroy) luaArray[i].call('onDestroy');
			if (destroy || luaArray[i].closed) luaArray[i].stop();
		}
		if (destroy) luaArray.resize(0);
	}

	function StrumPlayAnim(isDad:Bool, id:Int, time:Float = 0) {
		var grp = isDad ? strumLineNotes : playerStrums;
		var spr:StrumNote = grp.members[id];

		if (spr != null) {
			spr.playAnim('confirm', true);
			if (time > 0) spr.resetAnim = time;
		}
	}

	public var ratingName:String = '?';
	public var ratingPercent:Float;
	public var ratingFC:String;

	public var scoreFormat:String = 'Score: %score | Misses: %misses | Rating: %ratingName (%percent%) - %rating';
	public var noRatingScoreFormat:String = 'Score: %score | Misses: %misses | Rating: %ratingName';
	public function formatScore():String {
		var format = totalPlayed < 1 ? noRatingScoreFormat : scoreFormat;
		return format.replace('%score', Std.string(songScore)).replace('%misses', Std.string(songMisses)).replace('%ratingName', ratingName
			).replace('%percent', Std.string(Highscore.floorDecimal(ratingPercent * 100, 2))).replace('%rating', ratingFC);
	}

	public function updateScore(miss:Bool = false) {
		scoreTxt.text = formatScore();
		if (ClientPrefs.scoreZoom && !miss) {
			if (scoreTxtTween != null && !scoreTxtTween.finished)
				scoreTxtTween.cancel();

			scoreTxt.scale.set(1.075, 1.075);
			scoreTxtTween = FlxTween.tween(scoreTxt.scale, {x: 1, y: 1}, 0.2, {onComplete: function(_) {
				scoreTxtTween = null;
			}});
		}
		callOnLuas('onUpdateScore', [miss]);
	}

	public function RecalculateRating(badHit:Bool = false) {
		setOnLuas('score', songScore);
		setOnLuas('misses', songMisses);
		setOnLuas('hits', songHits);

		var ret:Dynamic = callOnLuas('onRecalculateRating', false);
		if(ret != FunkinLua.Function_Stop)
		{
			if(totalPlayed < 1) //Prevent divide by 0
				ratingName = '?';
			else
			{
				// Rating Percent
				ratingPercent = Math.min(1, Math.max(0, totalNotesHit / totalPlayed));
				//trace((totalNotesHit / totalPlayed) + ', Total: ' + totalPlayed + ', notes hit: ' + totalNotesHit);

				// Rating Name
				if(ratingPercent >= 1)
				{
					ratingName = ratingStuff[ratingStuff.length-1][0]; //Uses last string
				}
				else
				{
					for (i in 0...ratingStuff.length-1)
					{
						if(ratingPercent < ratingStuff[i][1])
						{
							ratingName = ratingStuff[i][0];
							break;
						}
					}
				}
			}

			// Rating FC
			ratingFC = "";
			if (sicks > 0) ratingFC = "SFC";
			if (goods > 0) ratingFC = "GFC";
			if (bads > 0 || shits > 0) ratingFC = "FC";
			if (songMisses > 0 && songMisses < 10) ratingFC = "SDCB";
			else if (songMisses >= 10) ratingFC = "Clear";
		}
		setOnLuas('rating', ratingPercent);
		setOnLuas('ratingName', ratingName);
		setOnLuas('ratingFC', ratingFC);
		updateScore(badHit); // score will only update after rating is calculated, if it's a badHit, it shouldn't bounce -Ghost
	}

	public function getActualPlaybackRate():Float {
		return FlxG.sound.music != null ? FlxG.sound.music.getActualPitch() : playbackRate;
	}

	#if ACHIEVEMENTS_ALLOWED
	private function checkForAchievement(achievesToCheck:Array<String> = null):String
	{
		if(chartingMode) return null;

		var usedPractice:Bool = (ClientPrefs.getGameplaySetting('practice', false) || ClientPrefs.getGameplaySetting('botplay', false));
		for (i in 0...achievesToCheck.length) {
			var achievementName:String = achievesToCheck[i];
			if(!Achievements.isAchievementUnlocked(achievementName) && !cpuControlled) {
				var unlock:Bool = false;
				
				if (achievementName.contains(WeekData.getWeekFileName()) && achievementName.endsWith('nomiss')) // any FC achievements, name should be "weekFileName_nomiss", e.g: "weekd_nomiss";
				{
					if(isStoryMode && campaignMisses + songMisses < 1 && CoolUtil.difficultyString() == 'HARD'
						&& storyPlaylist.length <= 1 && !changedDifficulty && !usedPractice)
						unlock = true;
				}
				switch(achievementName)
				{
					case 'ur_bad':
						if(ratingPercent < 0.2 && !practiceMode) {
							unlock = true;
						}
					case 'ur_good':
						if(ratingPercent >= 1 && !usedPractice) {
							unlock = true;
						}
					case 'roadkill_enthusiast':
						if(Achievements.henchmenDeath >= 100) {
							unlock = true;
						}
					case 'oversinging':
						if(boyfriend.holdTimer >= 10 && !usedPractice) {
							unlock = true;
						}
					case 'hype':
						if(!boyfriendIdled && !usedPractice) {
							unlock = true;
						}
					case 'two_keys':
						if(!usedPractice) {
							var howManyPresses:Int = 0;
							for (j in 0...keysUsed.length) {
								if(keysUsed[j]) howManyPresses++;
							}

							if(howManyPresses <= 2) {
								unlock = true;
							}
						}
					case 'toastie':
						if(/*ClientPrefs.framerate <= 60 &&*/ !ClientPrefs.shaders && ClientPrefs.lowQuality && !ClientPrefs.globalAntialiasing) {
							unlock = true;
						}
					case 'debugger':
						if(Paths.formatToSongPath(SONG.song) == 'test' && !usedPractice) {
							unlock = true;
						}
				}

				if(unlock) {
					Achievements.unlockAchievement(achievementName);
					return achievementName;
				}
			}
		}
		return null;
	}
	#end

	var curLight:Int = -1;
	var curLightEvent:Int = -1;
}
