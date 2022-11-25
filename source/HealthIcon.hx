package;

import flixel.graphics.FlxGraphic;
import flixel.FlxSprite;
import openfl.utils.Assets as OpenFlAssets;

using StringTools;

class HealthIcon extends FlxSprite
{
	public static var prefix(default, null):String = 'icons/';
	public static var defaultIcon(default, null):String = 'icon-face';

	public var sprTracker:FlxSprite;
	public var isOldIcon(get, null):Bool;
	public var isPlayer:Bool = false;

	private var char:String = '';
	private var availableStates:Int = 1;
	private var state:Int = 0;

	public static function returnGraphic(char:String, ?defaultIfMissing:Bool = false):FlxGraphic {
		var path:String = prefix + char;
		if (!Paths.fileExists('images/' + path + '.png', IMAGE)) path = prefix + 'icon-' + char; //Older versions of psych engine's support
		if (!Paths.fileExists('images/' + path + '.png', IMAGE)) { //Prevents crash from missing icon
			if (!defaultIfMissing) return null;
			path = prefix + defaultIcon;
		}
		return Paths.image(path);
	}

	public function new(char:String = 'bf', isPlayer:Bool = false) {
		this.isPlayer = isPlayer;

		super();
		scrollFactor.set();
		changeIcon(char);
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 12, sprTracker.y - 30);
	}

	public function swapOldIcon() {
		if (isOldIcon) changeIcon(char.substr(0, char.length - 4));
		else changeIcon(char + '-old');
	}

	private var iconOffsets:Array<Float> = [0, 0];
	public function changeIcon(char:String) {
		if (this.char == char) return;
		var graph:FlxGraphic = returnGraphic(char, true);

		if (graph == null) return;
		var ratio:Float = graph.width / graph.height;
		availableStates = Math.round(ratio);
		this.char = char;

		iconOffsets[1] = iconOffsets[0] = 0;
		if (availableStates <= 1) {
			loadGraphic(graph);
			updateHitbox();
			state = 0;
			return;
		}
		loadGraphic(graph, true, Math.floor(graph.width / availableStates), graph.height);
		updateHitbox();

		animation.add(char, [for (i in 0...availableStates) i], 0, false, isPlayer);
		animation.play(char);

		antialiasing = !char.endsWith('-pixel');
	}

	public function setState(state:Int) {
		if (state >= availableStates) state = 0;
		if (this.state == state || animation.curAnim == null) return;
		animation.curAnim.curFrame = this.state = state;
	}

	override function updateHitbox() {
		super.updateHitbox();
		offset.set(iconOffsets[0], iconOffsets[1]);
	}

	public function getCharacter():String
		return char;

	inline function get_isOldIcon():Bool
		return char.substr(-4, 3) == '-old';
}
