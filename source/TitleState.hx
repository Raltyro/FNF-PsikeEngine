package;

import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.graphics.frames.FlxFrame;
import flixel.input.keyboard.FlxKey;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.system.FlxSound;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.math.FlxMath;
import flixel.FlxSprite;
import flixel.FlxG;

import haxe.Json;

using StringTools;

typedef TitleData = {
	backgroundSprite:String,
	titleColors:String,
	titleAlphas:String,
	titlex:Float,
	titley:Float,
	startx:Float,
	starty:Float,
	gfx:Float,
	gfy:Float,
	bpm:Int
}

class TitleState extends MusicBeatState {
	public static var playJingle:Bool = false;
	public static var closedState:Bool = false;
	public static var initialized:Bool = false;

	var titleTextColors:Array<FlxColor> = [0xFF33FFFF, 0xFF3333CC];
	var titleTextAlphas:Array<Float> = [1, .64];
	var curWacky:Array<String> = [];

	var newTitle:Bool = false;
	var titleTimer:Float = 0;
	var titleJSON:TitleData;

	var swagShader:ColorSwap;

	var skippedIntro:Bool = false;
	var transitioning:Bool = false;

	var bg:FlxSprite;
	var logoBl:FlxSprite;
	var gfDance:FlxSprite;
	var titleText:FlxSprite;

	var textGroup:FlxTypedGroup<Alphabet>;
	var blackScreen:FlxSprite;
	var ngSpr:FlxSprite;

	#if TITLE_SCREEN_EASTER_EGG
	var easterEggKeys:Array<String> = [
		'SHADOW', 'RIVER', 'SHUBS', 'BBPANZU'
	];
	var allowedKeys:String = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
	var easterEggKeysBuffer:String = '';
	#end

	override function create() {
		Paths.clearUnusedMemory();

		WeekData.loadTheFirstEnabledMod();

		FlxTransitionableState.skipNextTransOut = true;
		persistentUpdate = true;
		persistentDraw = true;

		// Load the gf json shit for titlescreen
		titleJSON = Json.parse(Paths.getTextFromFile('images/gfDanceTitle.json'));

		// IGNORE THIS!!
		#if TITLE_SCREEN_EASTER_EGG
		if (FlxG.save.data.psychDevsEasterEgg == null) FlxG.save.data.psychDevsEasterEgg = '';
		switch(FlxG.save.data.psychDevsEasterEgg.toUpperCase()) {
			case 'SHADOW':
				titleJSON.gfx += 210;
				titleJSON.gfy += 40;
			case 'RIVER':
				titleJSON.gfx += 100;
				titleJSON.gfy += 20;
			case 'SHUBS':
				titleJSON.gfx += 160;
				titleJSON.gfy -= 10;
			case 'BBPANZU':
				titleJSON.gfx += 45;
				titleJSON.gfy += 100;
		}
		#end

		super.create();

		#if FREEPLAY
		MusicBeatState.switchState(new FreeplayState());
		#elseif CHARTING
		MusicBeatState.switchState(new ChartingState());
		#else
		if (FlxG.save.data.flashing == null && !FlashingState.leftState) {
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			MusicBeatState.switchState(new FlashingState());
		}
		else {
			createIntro();
			if (initialized && !playJingle) startIntro();
			else new FlxTimer().start(1, startIntro);
		}
		#end
	}

	function createIntro() {
		swagShader = new ColorSwap();

		bg = new FlxSprite();
		if (titleJSON.backgroundSprite != null && titleJSON.backgroundSprite.length > 0 && titleJSON.backgroundSprite != "none")
			bg.loadGraphic(Paths.image(titleJSON.backgroundSprite));
		else
			bg.makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);

		bg.antialiasing = ClientPrefs.globalAntialiasing;

		logoBl = new FlxSprite(titleJSON.titlex, titleJSON.titley);
		logoBl.antialiasing = ClientPrefs.globalAntialiasing;
		logoBl.shader = swagShader.shader;

		logoBl.frames = Paths.getSparrowAtlas('logoBumpin');
		logoBl.animation.addByPrefix('bump', 'logo bumpin', 24, false);
		logoBl.animation.play('bump');
		logoBl.updateHitbox();

		gfDance = new FlxSprite(titleJSON.gfx, titleJSON.gfy);
		gfDance.antialiasing = ClientPrefs.globalAntialiasing;
		gfDance.shader = swagShader.shader;

		var easterEgg:String = FlxG.save.data.psychDevsEasterEgg;
		if (easterEgg == null) easterEgg = '';
		easterEgg = easterEgg.toUpperCase();

		switch(easterEgg) {
			#if TITLE_SCREEN_EASTER_EGG
			case 'SHADOW':
				gfDance.frames = Paths.getSparrowAtlas('ShadowBump');
				gfDance.animation.addByPrefix('danceLeft', 'Shadow Title Bump', 24);
				gfDance.animation.addByPrefix('danceRight', 'Shadow Title Bump', 24);
			case 'RIVER':
				gfDance.frames = Paths.getSparrowAtlas('RiverBump');
				gfDance.animation.addByIndices('danceLeft', 'River Title Bump', [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], "", 24, false);
				gfDance.animation.addByIndices('danceRight', 'River Title Bump', [29, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], "", 24, false);
			case 'SHUBS':
				gfDance.frames = Paths.getSparrowAtlas('ShubBump');
				gfDance.animation.addByPrefix('danceLeft', 'Shub Title Bump', 24, false);
				gfDance.animation.addByPrefix('danceRight', 'Shub Title Bump', 24, false);
			case 'BBPANZU':
				gfDance.frames = Paths.getSparrowAtlas('BBBump');
				gfDance.animation.addByIndices('danceLeft', 'BB Title Bump', [14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27], "", 24, false);
				gfDance.animation.addByIndices('danceRight', 'BB Title Bump', [27, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13], "", 24, false);
			#end

			// EDIT THIS ONE IF YOU'RE MAKING A SOURCE CODE MOD!!!!
			// EDIT THIS ONE IF YOU'RE MAKING A SOURCE CODE MOD!!!!
			// EDIT THIS ONE IF YOU'RE MAKING A SOURCE CODE MOD!!!!
			default:
				gfDance.frames = Paths.getSparrowAtlas('gfDanceTitle');
				gfDance.animation.addByIndices('danceLeft', 'gfDance', [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], "", 24, false);
				gfDance.animation.addByIndices('danceRight', 'gfDance', [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], "", 24, false);
		}

		titleText = new FlxSprite(titleJSON.startx, titleJSON.starty);
		titleText.frames = Paths.getSparrowAtlas('titleEnter');

		var animFrames:Array<FlxFrame> = [];
		@:privateAccess {
			titleText.animation.findByPrefix(animFrames, "ENTER IDLE");
			titleText.animation.findByPrefix(animFrames, "ENTER FREEZE");
		}

		if (animFrames.length > 0) {
			newTitle = true;

			titleText.animation.addByPrefix('idle', "ENTER IDLE", 24);
			titleText.animation.addByPrefix('press', ClientPrefs.flashing ? "ENTER PRESSED" : "ENTER FREEZE", 24);
		}
		else {
			newTitle = false;

			titleText.animation.addByPrefix('idle', "Press Enter to Begin", 24);
			titleText.animation.addByPrefix('press', "ENTER PRESSED", 24);
		}

		titleText.antialiasing = ClientPrefs.globalAntialiasing;
		titleText.animation.play('idle');
		titleText.updateHitbox();

		textGroup = new FlxTypedGroup<Alphabet>();

		ngSpr = new FlxSprite(0, FlxG.height * 0.52).loadGraphic(Paths.image('newgrounds_logo'));
		ngSpr.antialiasing = ClientPrefs.globalAntialiasing;
		ngSpr.setGraphicSize(Std.int(ngSpr.width * 0.8));
		ngSpr.screenCenter(X);
		ngSpr.updateHitbox();
		ngSpr.visible = false;

		blackScreen = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);

		Paths.compress(8);
	}

	function startIntro(?_) {
		// force update the conductor
		Conductor.songPosition = 0;
		super.update(0);

		if (FreeplayState.vocals == null)
			Conductor.changeBPM(titleJSON.bpm);

		add(bg);

		add(logoBl);
		add(gfDance);
		add(titleText);

		add(blackScreen);

		add(textGroup);
		add(ngSpr);

		#if TITLE_SCREEN_EASTER_EGG
		var easterEgg:String = FlxG.save.data.psychDevsEasterEgg;
		if (easterEgg == null) easterEgg = '';
		easterEgg = easterEgg.toUpperCase();

		switch(easterEgg) {
			case 'RIVER':
				gfDance.animation.speed = Math.min(1.3, Conductor.bpm / 105.5);
		}
		#end

		if (initialized)
			skipIntro();
		else {
			curWacky = FlxG.random.getObject(getIntroTextShit());
			initialized = true;

			beatHit();
			sickBeats = curBeat + 1;
		}
	}

	function getIntroTextShit():Array<Array<String>> {
		var firstArray:Array<String> = CoolUtil.listFromString(Paths.getTextFromFile('data/introText.txt'));
		return [for (i in firstArray) i.split('--')];
	}

	override function update(elapsed:Float) {
		if (!initialized) return super.update(elapsed);

		if (!transitioning) {
			if (FlxG.sound.music == null) FlxG.sound.playMusic(Paths.music('freakyMenu'), 0.7);
			Conductor.songPosition = FlxG.sound.music.time;
		}
		else if (skippedIntro) Conductor.songPosition += elapsed * 1000;

		var pressedEnter:Bool = controls.ACCEPT;

		#if FLX_TOUCH
		for (touch in FlxG.touches.list) {
			if (touch.justPressed)
				pressedEnter = true;
		}
		#end

		if (swagShader != null) {
			if (controls.UI_LEFT) swagShader.hue -= elapsed * 0.1;
			if (controls.UI_RIGHT) swagShader.hue += elapsed * 0.1;
		}

		if (skippedIntro && newTitle && titleText.animation.curAnim.name == 'idle') {
			titleTimer += CoolUtil.boundTo(elapsed / 1.5, 0, 1);
			if (titleTimer > 2) titleTimer -= 2;

			var timer:Float = titleTimer;
			if (timer >= 1) timer = (-timer) + 2;
			timer = FlxEase.quadInOut(timer);

			titleText.color = FlxColor.interpolate(titleTextColors[0], titleTextColors[1], timer);
			titleText.alpha = FlxMath.lerp(titleTextAlphas[0], titleTextAlphas[1], timer);
		}

		if (!transitioning && skippedIntro) {
			if (pressedEnter) {
				titleText.animation.play('press');
				titleText.color = FlxColor.WHITE;
				titleText.alpha = 1;

				FlxG.camera.flash(ClientPrefs.flashing ? FlxColor.WHITE : 0x4CFFFFFF, 1);
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);

				transitioning = true;

				new FlxTimer().start(1, function(tmr:FlxTimer) {
					#if TITLE_SCREEN_EASTER_EGG
					var easterEgg:String = FlxG.save.data.psychDevsEasterEgg;
					if (easterEgg == null) easterEgg = '';
					easterEgg = easterEgg.toUpperCase();

					switch(easterEgg) {
						case 'SHADOW':
							FlxG.sound.music.fadeIn(4, 0, 0.7);
							if (FreeplayState.vocals != null) FreeplayState.vocals.fadeIn(4, 0, 0.7);
					}
					#end

					MusicBeatState.switchState(new MainMenuState());
					closedState = true;
				});
			}
			#if TITLE_SCREEN_EASTER_EGG
			else if (FlxG.keys.firstJustPressed() != FlxKey.NONE) {
				var keyPressed:FlxKey = FlxG.keys.firstJustPressed();
				var keyName:String = Std.string(keyPressed).toUpperCase();

				if (allowedKeys.contains(keyName)) {
					easterEggKeysBuffer += keyName;
					if (easterEggKeysBuffer.length >= 32) easterEggKeysBuffer = easterEggKeysBuffer.substring(1);

					for (wordRaw in easterEggKeys) {
						var word:String = wordRaw.toUpperCase(); //just for being sure you're doing it right

						if (easterEggKeysBuffer.length >= word.length && easterEggKeysBuffer.substr(easterEggKeysBuffer.length - word.length) == word) {
							//trace('YOOO! ' + word);

							if (FlxG.save.data.psychDevsEasterEgg == word) FlxG.save.data.psychDevsEasterEgg = '';
							else FlxG.save.data.psychDevsEasterEgg = word;
							FlxG.save.flush();

							FlxG.sound.play(Paths.sound('ToggleJingle'));

							// speed up the camera fxflashduration if it had one
							@:privateAccess FlxG.camera._fxFlashDuration /= FlxG.camera._fxFlashDuration;

							blackScreen.alpha = 0;
							add(blackScreen);

							FlxTween.tween(blackScreen, {alpha: 1}, 1, {onComplete:
								function(twn:FlxTween) {
									FlxTransitionableState.skipNextTransIn = true;
									FlxTransitionableState.skipNextTransOut = true;
									MusicBeatState.switchState(new TitleState());
								}
							});

							FlxG.sound.music.fadeOut();
							if (FreeplayState.vocals != null) FreeplayState.vocals.fadeOut();

							easterEggKeysBuffer = '';
							closedState = true;
							transitioning = true;
							playJingle = true;

							break;
						}
					}
				}
			}
			#end
		}

		if (pressedEnter && !skippedIntro)
			skipIntro();

		super.update(elapsed);
	}

	function createCoolText(textArray:Array<String>, offset:Float = 0) {
		for (i in 0...textArray.length) addMoreText(textArray[i], offset, i);
	}

	function addMoreText(text:String, offset:Float = 0, i:Int = -1) {
		var money:Alphabet = new Alphabet(0, ((i == -1 ? textGroup.length : i) * 60) + 200 + offset, text, true);
		money.screenCenter(X);

		textGroup.add(money);
	}

	function deleteCoolText() {
		while(textGroup.members.length > 0)
			textGroup.remove(textGroup.members[0], true);
	}

	private var sickBeats:Int = 0; //Basically curBeat but won't be skipped if you hold the tab or resize the screen
	private var danceLeft:Bool = false;
	override function beatHit() {
		super.beatHit();

		if (logoBl != null)
			logoBl.animation.play('bump', true);

		if (gfDance != null) {
			danceLeft = !danceLeft;
			if (danceLeft)
				gfDance.animation.play('danceRight');
			else
				gfDance.animation.play('danceLeft');
		}

		if (!closedState) {
			switch(sickBeats++) {
				case 0:
					#if PSYCH_WATERMARKS
					createCoolText(['Psych Engine by'], 15);
					#else
					createCoolText(['ninjamuffin99', 'phantomArcade', 'kawaisprite', 'evilsk8er']);
					#end
				case 3:
					#if PSYCH_WATERMARKS
					addMoreText('Shadow Mario', 15);
					addMoreText('RiverOaken', 15);
					addMoreText('shubs', 15);
					#else
					addMoreText('present');
					#end
				case 4:
					deleteCoolText();
				case 5:
					#if PSYCH_WATERMARKS
					createCoolText(['Not associated', 'with'], -40);
					#else
					createCoolText(['In association', 'with'], -40);
					#end
				case 7:
					addMoreText('newgrounds', -40);
					ngSpr.visible = true;
				case 8:
					deleteCoolText();
					ngSpr.visible = false;
				case 9:
					createCoolText([curWacky[0]]);
				case 11:
					addMoreText(curWacky[1]);
				case 12:
					deleteCoolText();
				case 13:
					addMoreText('Friday');
				case 14:
					addMoreText('Night');
				case 15:
					addMoreText('Funkin');
				case 16:
					skipIntro();
			}
		}
	}

	function skipIntro():Void {
		if (!skippedIntro) {
			// ignore deez
			#if TITLE_SCREEN_EASTER_EGG
			var easteregg:String = FlxG.save.data.psychDevsEasterEgg;
			if (easteregg == null) easteregg = '';
			easteregg = easteregg.toUpperCase();

			if (playJingle) {
				if (FreeplayState.vocals != null) FreeplayState.destroyFreeplayVocals();
				Conductor.mapBPMChanges(true);
				Conductor.changeBPM(titleJSON.bpm);

				var sound:FlxSound = null;
				switch(easteregg) {
					case 'RIVER':
						sound = FlxG.sound.play(Paths.sound('JingleRiver'));
					case 'SHUBS':
						sound = FlxG.sound.play(Paths.sound('JingleShubs'));
					case 'SHADOW':
						sound = FlxG.sound.play(Paths.sound('JingleShadow'));
					case 'BBPANZU':
						sound = FlxG.sound.play(Paths.sound('JingleBB'));

					default: // Go back to normal ugly ass boring GF
						FlxG.camera.flash(FlxColor.WHITE, 2);

						remove(ngSpr);
						remove(textGroup);
						remove(blackScreen);

						FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
						FlxG.sound.music.fadeIn(4, 0, 0.7);

						skippedIntro = true;
						playJingle = false;
						return;
				}

				Conductor.songPosition = -sound.length + (FlxG.elapsed * 1000);
				playJingle = false;
				switch(easteregg) {
					case 'SHADOW':
						FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
						transitioning = false;
					default:
						transitioning = true;

						sound.onComplete = function() {
							FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
							FlxG.sound.music.fadeIn(4, 0, 0.7);
							transitioning = false;
						};
				}
			}
			else {
				switch(easteregg) {
					case 'SHADOW':
						FlxG.sound.music.fadeOut();
						if (FreeplayState.vocals != null) FreeplayState.vocals.fadeOut();
				}
			}
			#end

			FlxG.camera.flash(FlxColor.WHITE, 4);

			remove(ngSpr);
			remove(textGroup);
			remove(blackScreen);

			skippedIntro = true;
		}
	}

	// for <0.6.3 luas
	public static var muteKeys(get, set):Array<FlxKey>;
	public static var volumeDownKeys(get, set):Array<FlxKey>;
	public static var volumeUpKeys(get, set):Array<FlxKey>;

	static function get_muteKeys():Array<FlxKey> return Main.muteKeys;
	static function set_muteKeys(v:Array<FlxKey>):Array<FlxKey> return Main.muteKeys = v;
	static function get_volumeDownKeys():Array<FlxKey> return Main.volumeDownKeys;
	static function set_volumeDownKeys(v:Array<FlxKey>):Array<FlxKey> return Main.volumeDownKeys = v;
	static function get_volumeUpKeys():Array<FlxKey> return Main.volumeUpKeys;
	static function set_volumeUpKeys(v:Array<FlxKey>):Array<FlxKey> return Main.volumeUpKeys = v;
}