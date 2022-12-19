package;

import openfl.utils.Assets as OpenFlAssets;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.math.FlxPoint;
import flixel.util.FlxDestroyUtil;

using StringTools;

class HealthIcon extends FlxSprite
{
	public static var prefix(default, null):String = 'icons/';
	public static var credits(default, null):String = 'credits/';
	public static var defaultIcon(default, null):String = 'icon-unknown';
	public static var altDefaultIcon(default, null):String = 'icon-face';

	public var iconOffsets:Array<Float> = [0, 0];
	public var iconZoom:Float = 1;
	public var sprTracker:FlxSprite;
	public var isOldIcon(get, null):Bool;
	public var isPixelIcon(get, null):Bool;
	public var isPlayer:Bool;
	public var isCredit:Bool;

	private var char:String = '';
	private var availableStates:Int = 1;
	private var state:Int = 0;
	private var _scale:FlxPoint;

	public static function returnGraphic(char:String, ?folder:String, defaultIfMissing:Bool = false, creditIcon:Bool = false):FlxGraphic {
		var path:String;
		if (creditIcon) {
			path = credits + ((folder != null || folder == '') ? folder + '/' : '') + char;
			if ((folder != null || folder == '') && !Paths.fileExists('images/' + path + '.png', IMAGE)) path = credits + char;
			if (Paths.fileExists('images/' + path + '.png', IMAGE)) return Paths.image(path);
			if (defaultIfMissing) return Paths.image(prefix + defaultIcon);
			return null;
		}
		path = prefix + char;
		if (!Paths.fileExists('images/' + path + '.png', IMAGE)) path = prefix + 'icon-' + char; //Older versions of psych engine's support
		if (!Paths.fileExists('images/' + path + '.png', IMAGE)) { //Prevents crash from missing icon
			if (!defaultIfMissing) return null;
			path = prefix + altDefaultIcon;
			if (!Paths.fileExists('images/' + path + '.png', IMAGE, false, true)) path = prefix + defaultIcon;
		}
		return Paths.image(path);
	}

	public function new(?char:String, ?folder:String, isPlayer:Bool = false, isCredit:Bool = false) {
		this.isPlayer = isPlayer;
		this.isCredit = isCredit;

		super();
		scrollFactor.set();
		changeIcon(char == null ? (isCredit ? defaultIcon : 'bf') : char, folder);
	}

	@:noCompletion
	override function initVars():Void {
		super.initVars();
		_scale = FlxPoint.get();
	}

	override function destroy():Void {
		super.destroy();
		_scale = FlxDestroyUtil.put(_scale);
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		if (sprTracker != null) setPosition(sprTracker.x + sprTracker.width + 12, sprTracker.y - 30);
	}

	override function draw() {
		if (iconZoom == 1) return super.draw();
		_scale.copyFrom(scale);
		scale.scale(iconZoom);
		super.draw();
		_scale.copyTo(scale);
	}

	public function swapOldIcon() {
		if (isOldIcon) changeIcon(char.substr(0, -4));
		else changeIcon(char + '-old');
	}

	public function changeIcon(char:String, ?folder:String, defaultIfMissing:Bool = true):Bool {
		if (this.char == char) return false;
		var graph:FlxGraphic = null;

		if (isCredit) graph = returnGraphic(char, folder, false, true);
		if (graph == null) graph = returnGraphic(char, defaultIfMissing);
		else {
			availableStates = 1;
			this.char = char;
			state = 0;

			iconOffsets[1] = iconOffsets[0] = 0;
			loadGraphic(graph, true, graph.width, graph.height);
			iconZoom = isPixelIcon ? 150 / graph.height : 1;

			animation.add(char, [0], 0, false, isPlayer);
			animation.play(char);

			updateHitbox();
			antialiasing = iconZoom < 2.5 && ClientPrefs.globalAntialiasing;
			return true;
		}

		if (graph == null) return false;
		var ratio:Float = graph.width / graph.height;
		availableStates = Math.round(ratio);
		this.char = char;
		state = 0;

		iconOffsets[1] = iconOffsets[0] = 0;
		loadGraphic(graph, true, Math.floor(graph.width / availableStates), graph.height);
		iconZoom = isPixelIcon ? 150 / graph.height : 1;

		animation.add(char, [for (i in 0...availableStates) i], 0, false, isPlayer);
		animation.play(char);

		updateHitbox();
		antialiasing = iconZoom < 2.5 && ClientPrefs.globalAntialiasing;
		return true;
	}

	public function setState(state:Int) {
		if (state >= availableStates) state = 0;
		if (this.state == state || animation.curAnim == null) return;
		animation.curAnim.curFrame = this.state = state;
	}

	override function updateHitbox() {
		super.updateHitbox();
		width *= iconZoom;
		height *= iconZoom;
		offset.set(
			-0.5 * (frameWidth * iconZoom - frameWidth) + iconOffsets[0],
			-0.5 * (frameHeight * iconZoom - frameHeight) + iconOffsets[1]
		);
	}

	public function getCharacter():String
		return char;

	@:noCompletion
	inline function get_isPixelIcon():Bool
		return char.substr(-6, 6) == '-pixel';

	@:noCompletion
	inline function get_isOldIcon():Bool
		return char.substr(-4, 4) == '-old';

	// funs
	private var squished:Bool = false;
	private var squishtweens:Array<FlxTween> = [];
	public function squish(squash:Bool) {
		if (squished == squash) return;
		FlxG.sound.play(Paths.soundRandom("squish" + (squash ? "in" : "out"), 1, 3), .7);
		setState(squash ? 1 : 0);
		squished = squash;

		for (v in squishtweens) if (v != null) v.cancel();
		squishtweens.resize(0);

		squishtweens.push(FlxTween.tween(scale,
			{y: squash ? .7 : 1, x: squash ? 1.2 : 1}, .85,
			{ease: FlxEase.elasticOut}
		));
		squishtweens.push(FlxTween.tween(offset,
			{y: iconOffsets[1] - (squash ? 8 : 0)}, .7,
			{ease: FlxEase.backOut}
		));
	}
}
