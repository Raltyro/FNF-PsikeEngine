package options;

import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.FlxG;

import Conductor.Rating;

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

	public var ratingSpr:RatingSpr;

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

		ratingSpr = new RatingSpr(this, {
			showRating: true,
			showCombo: false,
			showComboNum: true,
			isPixel: isPixelStage,

			rating: new Rating('sick'),
			diff: FlxG.random.float(-600, 600),
			combo: FlxG.random.int(50, 500)
		}, camHUD, false);

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

	override function update(elapsed:Float) {
		super.update(elapsed);

		Conductor.songPosition = FlxG.sound.music.time;
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
}