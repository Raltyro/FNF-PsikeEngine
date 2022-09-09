package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.effects.FlxFlicker;
import lime.app.Application;
import flixel.addons.transition.FlxTransitionableState;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;

using StringTools;

class OutdatedState extends MusicBeatState
{
	public static var leftState:Bool = false;
	
	private static var outdatedForkText:String =
	"Sup bro, looks like you're running an\n" +
	"Outdated version of Raltyro's Psych Engine Fork (%curVer)\n" +
	"Please Update to %updateVer\n\n" +
	"Press ENTER to update\nPress ESCAPE to proceed anyway\n\n" +
	"Thank you for using the Engine Fork!"
	;
	
	private static var outdatedUpstreamText:String =
	"Sup bro, looks like you're running an\n" +
	"Outdated version of Psych Engine (%curVer)\n" +
	"Please Update to %updateVer\n\n" +
	"Press ENTER to update\nPress ESCAPE to proceed anyway\n\n" +
	"Thank you for using the Engine!"
	;

	static function getOutdatedText(upstream:Bool):String {
		if (upstream)
			return outdatedUpstreamText.replace(
				"%curVer", MainMenuState.psychEngineVersion.trim() + "-" + CoolUtil.getGitCommitHash()
			).replace(
				"%updateVer", CoolUtil.upstreamVersion
			);
		
		return outdatedForkText.replace(
			"%curVer", MainMenuState.psychEngineVersion.trim() + "-" + CoolUtil.getGitCommitHash()
		).replace(
			"%updateVer", CoolUtil.updateVersion
		);
	}

	var warnText:FlxText;
	override function create()
	{
		super.create();
		
		leftState = false;

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(bg);
		
		var upstream:Bool = CoolUtil.updateVersion != CoolUtil.upstreamVersion;
		
		warnText = new FlxText(0, 0, FlxG.width, getOutdatedText(upstream), 32);
		warnText.setFormat("VCR OSD Mono", 32, FlxColor.WHITE, CENTER);
		warnText.screenCenter(Y);
		add(warnText);
	}

	override function update(elapsed:Float)
	{
		if(!leftState) {
			if (controls.ACCEPT) {
				leftState = true;
				CoolUtil.tryUpdate();
			}
			else if(controls.BACK) {
				leftState = true;
			}

			if(leftState)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				FlxTween.tween(warnText, {alpha: 0}, 1, {
					onComplete: function (twn:FlxTween) {
						MusicBeatState.switchState(new MainMenuState());
					}
				});
			}
		}
		super.update(elapsed);
	}
}
