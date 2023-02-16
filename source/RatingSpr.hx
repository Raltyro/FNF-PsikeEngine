// if anybody wants to make a pr for to change this to FlxGroup, i would highly appreciate it 💕

package;

import flixel.tweens.misc.VarTween;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.group.FlxGroup;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.FlxBasic;
import flixel.FlxG;

import Conductor.Rating;

typedef RatingData = {
	var ?showRating:Bool;
	var ?showCombo:Bool;
	var ?showComboNum:Bool;
	var ?isPixel:Bool;
	var ?speedRate:Float;

	var rating:Rating;
	var diff:Float;
	var combo:Int;
}

class RatingSpr {
	public static var pixelZoom:Float = PlayState.daPixelZoom;

	public var data:RatingData;
	public var parent:FlxGroup;
	public var camera:FlxCamera;
	public var layer:Int;

	public var rating:FlxSprite;
	public var combo:FlxSprite;
	public var comboNums:Array<FlxSprite>;
	public var diffNums:Array<FlxSprite>;

	public function new(parent:FlxGroup, data:RatingData, ?camera:FlxCamera, ?layer:Int = -1, popUp:Bool = true) {
		this.parent = parent;
		this.data = data;
		this.camera = camera;
		this.layer = layer;

		reload(data);
		if (popUp) pop();
	}

	public function pop() {
		var speedRate:Float = data.speedRate != null ? data.speedRate : 1;

		rating.velocity.set(FlxG.random.int(-5, 5) * speedRate, -FlxG.random.int(140, 175) * speedRate);
		rating.acceleration.y = 550 * speedRate * speedRate;

		combo.velocity.set(FlxG.random.int(-5, 5) * speedRate, -FlxG.random.int(140, 160) * speedRate);
		combo.acceleration.y = FlxG.random.int(200, 300) * speedRate * speedRate;

		for (numScore in comboNums) {
			numScore.velocity.set(FlxG.random.float(-5, 5) * speedRate, -FlxG.random.int(140, 160) * speedRate);
			numScore.acceleration.y = FlxG.random.int(200, 300) * speedRate * speedRate;

			FlxTween.tween(numScore, {alpha: 0}, 0.2 / speedRate, {
				startDelay: Conductor.crochet * 0.002 / speedRate
			});
		}

		FlxTween.tween(rating, {alpha: 0}, 0.2 / speedRate, {
			startDelay: Conductor.crochet * 0.001 / speedRate
		});

		FlxTween.tween(combo, {alpha: 0}, 0.2 / speedRate, {
			startDelay: Conductor.crochet * 0.002 / speedRate,
			onComplete: destroy
		});
	}

	public function reload(?data:RatingData) {
		destroy();

		if (data == null) data = this.data;
		comboNums = [];
		diffNums = [];

		var daRating:Rating = data.rating;
		var placement:String = Std.string(Math.abs(data.combo));
		var diffStr:String = Std.string(Math.abs(data.diff));
		var showRating:Bool = data.showRating != null ? data.showRating : true;
		var showCombo:Bool = data.showCombo != null ? data.showCombo : false;
		var showComboNum:Bool = data.showComboNum != null ? data.showComboNum : true;
		var isPixel:Bool = data.isPixel != null ? data.isPixel : false;
		var speedRate:Float = data.speedRate != null ? data.speedRate : 1;

		var p1:String = '';
		var p2:String = '';
		if (isPixel) {
			p1 = 'pixelUI/';
			p2 = '-pixel';
		}

		var sepCombo:Array<String> = [for (i in 0...(3-placement.length)) '0'];
		for (i in 0...placement.length) sepCombo.push(placement.charAt(i));
		if (data.combo < 0) sepCombo.unshift('negative');

		var sepDiff:Array<String> = [for (i in 0...(3-diffStr.length)) '0'];
		for (i in 0...diffStr.length) sepDiff.push(diffStr.charAt(i));
		if (data.diff < 0) sepDiff.unshift('negative');
		else sepDiff.push('plus');

		rating = new FlxSprite().loadGraphic(Paths.image(p1 + daRating.image + p2));
		rating.visible = !ClientPrefs.hideHud && showRating;

		combo = new FlxSprite().loadGraphic(Paths.image(p1 + 'combo' + p2));
		combo.visible = !ClientPrefs.hideHud && showCombo;

		if (isPixel) {
			rating.scale.set(pixelZoom * 0.8, pixelZoom * 0.8);
			combo.scale.set(pixelZoom * 0.63, pixelZoom * 0.63);
		}
		else {
			rating.antialiasing = combo.antialiasing = ClientPrefs.globalAntialiasing;
			rating.scale.set(0.7, 0.7);
			combo.scale.set(0.52, 0.52);
		}
		rating.updateHitbox();
		combo.updateHitbox();

		addToParent(rating);
		addToParent(combo);

		var numScore:FlxSprite;

		for (i in sepCombo) {
			numScore = new FlxSprite().loadGraphic(Paths.image(p1 + 'num$i' + p2));
			numScore.visible = !ClientPrefs.hideHud && showComboNum;

			if (isPixel)
				numScore.scale.set(pixelZoom * 0.8, pixelZoom * 0.8);
			else {
				numScore.antialiasing = ClientPrefs.globalAntialiasing;
				numScore.scale.set(0.5, 0.5);
			}
			numScore.updateHitbox();

			addToParent(numScore);
			comboNums.push(numScore);
		}

		reposition();
	}

	public function setProperties(prop:String, val:Dynamic) {
		if (rating != null) Reflect.setProperty(rating, prop, val);
		if (combo != null) Reflect.setProperty(combo, prop, val);
		if (comboNums != null) for (v in comboNums) Reflect.setProperty(v, prop, val);
		if (diffNums != null) for (v in diffNums) Reflect.setProperty(v, prop, val);
	}

	public function reposition() {
		rating.screenCenter();
		rating.setPosition(rating.x - 90, rating.y - 80);
		rating.x += ClientPrefs.comboOffset[0];
		rating.y -= ClientPrefs.comboOffset[1];

		var i:Int = 0;
		var offset:Float = CoolUtil.boundTo(comboNums.length - 3, 0, 999);
		var lastNum:FlxSprite = null;
		for (num in comboNums) {
			num.screenCenter();
			num.setPosition((i - offset) * 43 + num.x - 260, num.y + 56);
			num.x += ClientPrefs.comboOffset[2];
			num.y -= ClientPrefs.comboOffset[3];

			lastNum = num;
			i++;
		}

		if (lastNum != null) combo.setPosition(lastNum.x + 50, lastNum.y - 5);
	}

	private function addToParent(v:FlxBasic) {
		if (layer == -1) parent.add(v);
		else parent.insert(layer, v);
		if (camera != null) v.camera = camera;
	}

	public function destroy(?_) {
		if (rating != null && rating.exists) {
			parent.remove(rating);
			rating.destroy();
		}
		if (combo != null && combo.exists) {
			parent.remove(combo);
			combo.destroy();
		}
		if (comboNums != null) {
			var i:Int = comboNums.length;
			while (--i >= 0) {
				parent.remove(comboNums[i]);
				comboNums[i].destroy();
			}
			comboNums.resize(0);
			comboNums = null;
		}
	}
}