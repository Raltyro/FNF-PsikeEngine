package options;

import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.FlxG;

class NoteOffsetState extends MusicBeatState {
	public static var daPixelZoom:Float = PlayState.daPixelZoom;
	public var isPixelStage:Bool = false;

	public var BF_X:Float = 770;
	public var BF_Y:Float = 100;
	public var GF_X:Float = 400;
	public var GF_Y:Float = 130;

	public var boyfriendGroup:FlxSpriteGroup;
	public var gfGroup:FlxSpriteGroup;

	public var boyfriend:Character;
	public var gf:Character;

	public var camHUD:FlxCamera;
	public var camGame:FlxCamera;
	public var camOther:FlxCamera;
	public var cameraSpeed:Float = 1;

	public var rating:FlxSprite;
	public var comboSpr:FlxSprite;
	public var comboNums:FlxSpriteGroup;

	var defaultCamZoom:Float = 1;

	override function create() {
		FlxG.sound.destroy(true);

		camGame = new FlxCamera();
		camHUD = new FlxCamera();
		camOther = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		camOther.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOther, false);

		FlxG.cameras.setDefaultDrawTarget(camGame, true);
		CustomFadeTransition.nextCamera = camOther;

		persistentUpdate = true;

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

		makeCombo();

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

	inline function makeCombo():Void {
		var showRating:Bool = true;
		var showCombo:Bool = true;
		var showComboNum:Bool = true;

		if (rating != null && rating.exists) {
			showRating = rating.visible;
			remove(rating);
			rating.destroy();
		}
		if (comboSpr != null && comboSpr.exists) {
			showCombo = comboSpr.visible;
			remove(comboSpr);
			comboSpr.destroy();
		}
		if (comboNums != null && comboNums.exists) {
			showComboNum = comboNums.visible;
			remove(comboNums);
			comboNums.destroy();
		}

		var seperatedScore:Array<Int> = [for (i in 0...3) FlxG.random.int(0, 9)];

		var p1:String = '';
		var p2:String = '';
		if (isPixelStage) {
			p1 = 'pixelUI/';
			p2 = '-pixel';
		}

		rating = new FlxSprite().loadGraphic(Paths.image(p1 + 'sick' + p2));
		rating.visible = showRating;

		comboSpr = new FlxSprite().loadGraphic(Paths.image(p1 + 'combo' + p2));
		comboSpr.visible = showCombo;

		comboNums = new FlxSpriteGroup();
		comboNums.visible = showComboNum;

		if (isPixelStage) {
			rating.scale.set(daPixelZoom * 0.8, daPixelZoom * 0.8);
			comboSpr.scale.set(daPixelZoom * 0.56, daPixelZoom * 0.56);
		}
		else {
			rating.antialiasing = comboSpr.antialiasing = ClientPrefs.globalAntialiasing;
			rating.scale.set(0.7, 0.7);
			comboSpr.scale.set(0.5, 0.5);
		}
		rating.updateHitbox();
		comboSpr.updateHitbox();

		var daLoop:Int = 0;
		var numScore:FlxSprite;

		for (i in seperatedScore) {
			numScore = new FlxSprite(43 * daLoop).loadGraphic(Paths.image(p1 + 'num$i' + p2));

			if (isPixelStage)
				numScore.scale.set(daPixelZoom * 0.8, daPixelZoom * 0.8);
			else {
				numScore.antialiasing = ClientPrefs.globalAntialiasing;
				numScore.scale.set(0.5, 0.5);
			}
			numScore.updateHitbox();

			comboNums.add(numScore);
			daLoop++;
		}

		comboNums.cameras = rating.cameras = comboSpr.cameras = [camHUD];
		add(rating);
		add(comboSpr);
		add(comboNums);

		repositionCombo();
	}

	override function update(elapsed:Float) {
		Conductor.songPosition = FlxG.sound.music.time;
		super.update(elapsed);

		camGame.zoom = FlxMath.lerp(camGame.zoom, defaultCamZoom, CoolUtil.boundTo(elapsed * 3.125, 0, 1));

		if (controls.BACK) {
			persistentUpdate = false;
			CustomFadeTransition.nextCamera = camOther;
			MusicBeatState.switchState(new options.OptionsState());
			FlxG.sound.playMusic(Paths.music('freakyMenu'), 1, true);
			FlxG.mouse.visible = false;
		}
	}

	override function sectionHit() {
		super.sectionHit();

		if (camGame.zoom < 1.35)
			camGame.zoom += 0.015;
	}

	function repositionCombo():Void {
		var coolX:Float = FlxG.width * 0.35;

		rating.setPosition(
			(FlxG.width - rating.frameWidth) / 2 * 0.9 - 20 + ClientPrefs.comboOffset[0],
			(FlxG.width - rating.frameHeight) / 2 - 60 - ClientPrefs.comboOffset[1]
		);
		comboNums.setPosition(
			coolX - 90 + ClientPrefs.comboOffset[2],
			(FlxG.width - (comboNums.height / .5)) / 2 + 80 - ClientPrefs.comboOffset[3]
		);
		comboSpr.setPosition(
			comboNums.members[comboNums.length - 1].x + 50,
			(FlxG.height - comboSpr.frameHeight) / 2 + 80 - ClientPrefs.comboOffset[3]
		);
	}
}