package options;

import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.FlxObject;
import flixel.FlxG;

import Discord.DiscordClient;
import Controls.Action;
import Conductor.Rating;

class NoteOffsetState extends MusicBeatState {
	public static var daPixelZoom:Float = PlayState.daPixelZoom;
	public var onComboMenu:Bool = true;
	public var isPixelStage:Bool = false;

	public var BF_X:Float = 770;
	public var BF_Y:Float = 100;
	public var GF_X:Float = 400;
	public var GF_Y:Float = 130;

	public var camHUD:FlxCamera;
	public var camGame:FlxCamera;
	public var camOther:FlxCamera;
	public var cameraSpeed:Float = 1;
	public var defaultCamZoom:Float = 1;

	var boyfriendGroup:FlxSpriteGroup;
	var gfGroup:FlxSpriteGroup;

	var boyfriend:Character;
	var gf:Character;

	var dumbTexts:FlxTypedGroup<FlxText>;
	var modeConfigText:FlxText;
	var ratingSpr:RatingSpr;

	var mouse:FlxSprite;
	var holdingObjectOffset:FlxPoint;
	var nativeHoldingObject:Bool = false;
	var holdingObject:Int = -1;

	override function create() {
		#if desktop
		DiscordClient.changePresence('Note Offsets and Combo Pop-up Setting', null);
		#end

		FlxG.fixedTimestep = false;
		persistentUpdate = true;

		FlxG.sound.destroy(true);
		Paths.clearUnusedMemory();

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

		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);

		makeStage();

		// Characters
		gfGroup = new FlxSpriteGroup(GF_X, GF_Y);
		boyfriendGroup = new FlxSpriteGroup(BF_X, BF_Y);

		gf = new Character(0, 0, 'gf');
		gf.x += gf.positionArray[0];
		gf.y += gf.positionArray[1];
		gf.scrollFactor.set(0.95, 0.95);
		gf.danceEveryNumBeats = 2;
		gfGroup.add(gf);

		boyfriend = new Character(0, 0, 'bf', true);
		boyfriend.x += boyfriend.positionArray[0];
		boyfriend.y += boyfriend.positionArray[1];
		boyfriendGroup.add(boyfriend);

		add(gfGroup);
		add(boyfriendGroup);

		makeForeStage();

		// Combos popup
		ratingSpr = new RatingSpr(this, {
			showRating: true,
			showCombo: false,
			showComboNum: true,
			isPixel: isPixelStage,

			rating: new Rating('sick'),
			diff: FlxG.random.float(-600, 600),
			combo: FlxG.random.int(50, 500)
		}, camHUD, false);

		// UI
		dumbTexts = new FlxTypedGroup<FlxText>();
		dumbTexts.cameras = [camHUD];
		add(dumbTexts);
		for (i in 0...6) createText(i);

		var blackBox:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, 40, FlxColor.BLACK);
		blackBox.scrollFactor.set();
		blackBox.camera = camHUD;
		blackBox.alpha = 0.6;
		add(blackBox);

		modeConfigText = new FlxText(0, 4, FlxG.width, "", 32).setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
		modeConfigText.scrollFactor.set();
		modeConfigText.camera = camHUD;
		add(modeConfigText);

		updateMode();

		// mouse
		mouse = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		mouse.setGraphicSize(18);
		mouse.updateHitbox();
		mouse.screenCenter();
		mouse.camera = camHUD;
		add(mouse);

		holdingObjectOffset = FlxPoint.get();

		Conductor.changeBPM(128.0);
		FlxG.sound.playMusic(Paths.music('offsetSong'), 1, true);

		super.create();
	}

	inline function makeStage():Void {
		camGame.scroll.set(120, 130);

		var bg:BGSprite = new BGSprite('stageback', -600, -200, 0.9, 0.9);
		add(bg);

		var stageFront:BGSprite = new BGSprite('stagefront', -650, 600, 0.9, 0.9);
		stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
		stageFront.updateHitbox();
		add(stageFront);
	}

	inline function makeForeStage():Void {
		if (!ClientPrefs.lowQuality) {
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

	function updateMode() {
		ratingSpr.setProperties('alpha', onComboMenu ? 1 : .5);

		if (onComboMenu) modeConfigText.text = '< Combo Offset (Hold Accept to Switch) >';
		else modeConfigText.text = '< Note/Beat Delay (Hold Accept to Switch) >';

		modeConfigText.text = modeConfigText.text.toUpperCase();
		FlxG.mouse.visible = onComboMenu;
	}

	function createText(i:Int) {
		var text:FlxText = new FlxText(10, 48 + (i * 30), 0, '', 24);
		text.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		text.scrollFactor.set();
		text.borderSize = 2;
		text.camera = camHUD;

		dumbTexts.add(text);
		text.y += Math.floor(i / 2) * 24;
	}

	function reloadTexts() {
		if (onComboMenu) {
			setDumbText(0, 'Rating Offset:', '[${ClientPrefs.comboOffset[0]}, ${ClientPrefs.comboOffset[1]}]');
			setDumbText(1, 'Combo Numbers Offset:', '[${ClientPrefs.comboOffset[2]}, ${ClientPrefs.comboOffset[3]}]');
			setDumbText(2, 'Precision Numbers Offset:', '[${ClientPrefs.comboOffset[4]}, ${ClientPrefs.comboOffset[5]}]');
		}
		else {
			setDumbText(0, '', '');
			setDumbText(1, '', '');
			setDumbText(2, '', '');
		}
	}

	function setDumbText(i:Int, text1:String, text2:String) {
		i = Math.floor(i * 2);

		var m = dumbTexts.members;
		if (m[i] != null && m[i].text != text1) m[i].text = text1;
		if (m[i + 1] != null && m[i + 1].text != text2) m[i + 1].text = text2;
	}

	var acceptTime:Float = 0;
	override function update(elapsed:Float) {
		Conductor.songPosition = FlxG.sound.music.time;
		super.update(elapsed);

		camGame.zoom = FlxMath.lerp(camGame.zoom, defaultCamZoom, CoolUtil.boundTo(elapsed * 3.125, 0, 1));

		if (controls.ACCEPT_H && holdingObject == -1) acceptTime += elapsed;
		else acceptTime = 0;

		if (acceptTime > .5) {
			acceptTime = -999999;
			onComboMenu = !onComboMenu;
			updateMode();
		}

		updateHoldTimeKey(elapsed);
		updateInput(elapsed);

		if (controls.BACK) {
			persistentUpdate = false;
			CustomFadeTransition.nextCamera = camOther;
			MusicBeatState.switchState(new options.OptionsState());
			FlxG.sound.playMusic(Paths.music('freakyMenu'), 1, true);
			FlxG.mouse.visible = false;
		}

		ratingSpr.reposition();
		reloadTexts();
	}

	function updateInput(elapsed:Float) {
		var addNum = (FlxG.keys.pressed.SHIFT || controls.PAUSE_H) ? 2.5 : 1;
		var left = controls.UI_LEFT;
		var down = controls.UI_DOWN;
		var up = controls.UI_UP;
		var right = controls.UI_RIGHT;

		mouse.x += (left ? -1 : right ? 1 : 0) * 300 * addNum * elapsed;
		mouse.y += (down ? 1 : up ? -1 : 0)  * 300 * addNum * elapsed;
		mouse.alpha = (controls.ACCEPT_H ? .8 : .5) / (onComboMenu ? 1 : 2);

		if (onComboMenu) {
			if (holdingObject != -1 && (nativeHoldingObject ? FlxG.mouse.justReleased : controls.ACCEPT)) {
				ratingSpr.setProperties('alpha', 1);
				modeConfigText.alpha = 1;

				var v = holdingObject * 2;
				mouse.x = ClientPrefs.comboOffset[v] + holdingObjectOffset.x;
				mouse.y = ClientPrefs.comboOffset[v + 1] + holdingObjectOffset.y;

				holdingObject = -1;
			}

			if (FlxG.mouse.justPressed || controls.ACCEPT) {
				nativeHoldingObject = !controls.ACCEPT;
				if (nativeHoldingObject) mouse.setPosition(FlxG.mouse.x, FlxG.mouse.y);

				holdingObject = getOverlappedObject(mouse);
				if (holdingObject != -1) {
					var v = holdingObject * 2;
					for (i in 0...3) setObjectAlpha(i, i == holdingObject ? 1 : .5);
					modeConfigText.alpha = .5;

					holdingObjectOffset.x = ClientPrefs.comboOffset[v] - (nativeHoldingObject ? FlxG.mouse.x : mouse.x);
					holdingObjectOffset.y = -ClientPrefs.comboOffset[v + 1] - (nativeHoldingObject ? FlxG.mouse.y : mouse.y);
				}
			}

			if (holdingObject != -1) {
				var v = holdingObject * 2;
				ClientPrefs.comboOffset[v] = Math.floor((nativeHoldingObject ? FlxG.mouse.x : mouse.x) + holdingObjectOffset.x);
				ClientPrefs.comboOffset[v + 1] = -Math.floor((nativeHoldingObject ? FlxG.mouse.y : mouse.y) + holdingObjectOffset.y);
			}

			if (controls.RESET) {
				for (i in 0...ClientPrefs.comboOffset.length)
					ClientPrefs.comboOffset[i] = 0;
			}
		}
		else {
			
		}
	}

	function setObjectAlpha(i:Int, alpha:Float) {
		var obj = i == 0 ? ratingSpr.rating : (i == 1 ? ratingSpr.combo : null);
		if (obj != null) obj.alpha = alpha;

		var arr = i == 1 ? ratingSpr.comboNums : (i == 2 ? ratingSpr.diffNums : null);
		if (arr != null) for (v in arr) obj.alpha = alpha;
	}

	function getOverlappedObject(pos:FlxObject):Int {
		if (ratingSpr.rating != null && ratingSpr.rating.overlaps(pos)) return 0;
		if (ratingSpr.combo != null && ratingSpr.combo.overlaps(pos)) return 1;
		if (ratingSpr.comboNums != null) for (v in ratingSpr.comboNums) if (v.overlaps(pos)) return 1;
		if (ratingSpr.diffNums != null) for (v in ratingSpr.diffNums) if (v.overlaps(pos)) return 2;
		return -1;
	}

	override function beatHit() {
		if (!onComboMenu && camGame.zoom < 1.35)
			camGame.zoom += 0.0075;

		if (curBeat % 2 == 0) boyfriend.dance();
		gf.dance();
	}

	override function sectionHit() {
		super.sectionHit();

		if (camGame.zoom < 1.35)
			camGame.zoom += 0.015;
	}

	// stupid ass keys
	var holdKeys:Map<Action, Float> = [];
	function updateHoldTimeKey(elapsed:Float):Void {
		for (key in holdKeys.keys()) if (holdKeys.get(key) > -1) holdKeys.set(key, holdKeys.get(key) + elapsed);
	}

	function getHoldTimeKey(act:Action):Float {
		if (holdKeys.get(act) == null) holdKeys.set(act, -1);

		if (Reflect.getProperty(controls, act)) {
			if (holdKeys.get(act) == -1) holdKeys.set(act, 0);
		}
		else if (holdKeys.get(act) > -1) holdKeys.set(act, -1);

		return holdKeys.get(act);
	}
}