package options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;

using StringTools;

class AdvancedSubstate extends BaseOptionsMenu
{
	var blackBG:FlxSprite;
	var coolText:Alphabet;
	var timer:FlxTimer;

	public function new()
	{
		title = 'Advanced';
		rpcTitle = 'Advanced Settings Menu'; // for Discord Rich Presence

		blackBG = new FlxSprite().makeGraphic(1, 1, 0xFF000000);
		blackBG.setGraphicSize(FlxG.width, FlxG.height);
		blackBG.updateHitbox();
		blackBG.alpha = 0;

		coolText = new Alphabet(FlxG.width / 2, (FlxG.height / 2) - 25, "", true);
		coolText.alignment = CENTERED;
		coolText.alpha = 0;

		timer = new FlxTimer();

		var option:Option = new Option('Hardware Caching',
			'If checked, the game will use GPU to store images for to maintain MEM usage. ' +
			'Restart the game for to apply changes.' +
			'\n[UNCHECK THIS IF IMAGES ARE NOT SHOWING]',
			'hardwareCache',
			'bool',
			false);
		addOption(option);

		#if desktop
		var option:Option = new Option('Streaming Music',
			'If checked, the game will simultaneously load music data while its playing, this also make looped musics seamlessly loop. ' +
			'Restart the game for to apply changes.' +
			'\n[UNCHECK THIS IF GAME IS CRASHING]',
			'streamMusic',
			'bool',
			true);
		addOption(option);
		#end

		var option:Option = new Option('FPS Counter',
			'If unchecked, hides FPS Counter.',
			'showFPS',
			'bool',
			true);
		addOption(option);
		option.onChange = onChangeCounter;

		var option:Option = new Option('Memory Counter',
			'If unchecked, hides Memory Counter.',
			'showMem',
			'bool',
			true);
		addOption(option);
		option.onChange = onChangeCounter;

		var option:Option = new Option('Memory Peak Counter',
			'If unchecked, hides Memory Peak Counter.',
			'showMemPeak',
			'bool',
			true);
		addOption(option);
		option.onChange = onChangeCounter;
		
		var option:Option = new Option('Garbage Collector Counter',
			'If unchecked, hides Garbage Collector Counter.',
			'showGc',
			'bool',
			true);
		addOption(option);
		option.onChange = onChangeCounter;

		var option:Option = new Option('GL Statistics Counter',
			'If unchecked, hides GL Statistics Counter.',
			'showGLStats',
			'bool',
			true);
		addOption(option);
		option.onChange = onChangeCounter;
		
		var option:Option = new Option('Check for Updates at Start',
			'On Release builds, turn this on to check for updates when you start the game.',
			'checkForUpdates',
			'bool',
			true);
		addOption(option);
		
		var option:Option = new Option('Check for Updates',
			'If pressed, it will check for updates.',
			null,
			'button',
			true);
		addOption(option);
		option.onChange = onPressUpdates;

		super();
	}
	
	function onChangeCounter()
	{
		if(Main.fpsVar != null) {
			Main.fpsVar.showFPS = ClientPrefs.showFPS;
			Main.fpsVar.showMem = ClientPrefs.showMem;
			Main.fpsVar.showMemPeak = ClientPrefs.showMemPeak;
			Main.fpsVar.showGc = ClientPrefs.showGc;
			Main.fpsVar.showGLStats = ClientPrefs.showGLStats;
		}
	}

	function onPressUpdates()
	{
		canInteract = false;

		coolText.text = "Checking for Updates...";
		
		add(blackBG);
		add(coolText);

		FlxTween.tween(blackBG, {alpha: .5}, 0.7, {ease: FlxEase.linear});
		FlxTween.tween(coolText, {alpha: 1}, 0.7, {
			ease: FlxEase.linear,
			onComplete: function(_:FlxTween) {
				CoolUtil.checkForUpdates(function(mustUpdate:Bool) {
					coolText.text = mustUpdate ? "Updates found!" : "No Updates found!";

					timer.start(1.5, function(_:FlxTimer) {
						if (mustUpdate) MusicBeatState.switchState(new OutdatedState());
						else {
							FlxTween.tween(blackBG, {alpha: 0}, 0.7, {ease: FlxEase.linear});
							FlxTween.tween(coolText, {alpha: 0}, 0.7, {
								ease: FlxEase.linear,
								onComplete: function(_:FlxTween) {
									canInteract = true;

									remove(blackBG);
									remove(coolText);
								}
							});
						}
					});
				});
			}
		});
	}
}