package openfl.display;

import haxe.Timer;
import openfl.events.Event;
import openfl.text.TextField;
import openfl.text.TextFormat;
import flixel.math.FlxMath;
#if gl_stats
import openfl.display._internal.stats.Context3DStats;
import openfl.display._internal.stats.DrawCallContext;
#end
import openfl.Lib;

#if openfl
import openfl.system.System;
#end

#if windows
@:headerCode("
#include <windows.h>
#include <psapi.h>
")
#elseif linux
@:headerCode("
#include <unistd.h>
#include <sys/resource.h>

#include <stdio.h>
")
#else
#if cpp
import cpp.vm.Gc;
#elseif hl
import hl.Gc;
#elseif java
import java.vm.Gc;
#elseif neko
import neko.vm.Gc;
#end
#end

/**
	The FPS class provides an easy-to-use monitor to display
	the current frame rate of an OpenFL project
**/
#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
class FPS extends TextField
{
	/**
		The current frame rate, expressed using frames-per-second
	**/
	public var currentFPS(default, null):Int;
	public var currentMem(default, null):Float;
	public var currentMemPeak(default, null):Float;
	
	public var showFPS:Bool = true;
	public var showMem:Bool = false;
	public var showMemPeak:Bool = false;
	public var inEditor:Bool = false;

	@:noCompletion private var cacheCount:Int;
	@:noCompletion private var currentTime:Float;
	@:noCompletion private var times:Array<Float>;

	public function new(x:Float = 3, y:Float = 3, color:Int = 0x000000, showFPS:Bool = true, showMem:Bool = false)
	{
		super();

		currentFPS = 0;
		currentMem = 0;
		currentMemPeak = 0;
		
		this.x = x;
		this.y = y;
		selectable = false;
		mouseEnabled = false;
		defaultTextFormat = new TextFormat(Paths.font("vcr.ttf"), 16, color);

		width = 400;
		height = 70;
		
		autoSize = LEFT;
		multiline = true;

		cacheCount = 0;
		currentTime = 0;
		times = [];

		#if flash
		addEventListener(Event.ENTER_FRAME, function(e)
		{
			var time = Lib.getTimer();
			__enterFrame(time - currentTime);
		});
		#end
	}

	// Event Handlers
	@:noCompletion
	private #if !flash override #end function __enterFrame(deltaTime:Float):Void
	{
		var canRender:Bool = visible && (showFPS || showMem || showMemPeak);
		
		currentTime += deltaTime;
		times.push(currentTime);

		while (times[0] < currentTime - 1000)
		{
			times.shift();
		}

		var currentCount = times.length;
		currentFPS = Math.round((currentCount + cacheCount) / 2);
		if (currentFPS > ClientPrefs.framerate) currentFPS = ClientPrefs.framerate;
		
		currentMem = (get_totalMemory() / 1024) / 1000;
		#if (windows || linux)
		var memPeak:Float = (get_memPeak() / 1024) / 1000;
		if (memPeak > currentMemPeak) currentMemPeak = memPeak;
		#else
		if (currentMem > currentMemPeak) currentMemPeak = currentMem;
		#end

		if (canRender) {
			if (currentCount != cacheCount) {
				if (currentMem > 3000 || currentFPS <= ClientPrefs.framerate / 2)
					textColor = 0xFFFF0000;
				else
					textColor = 0xFFFFFFFF;
				
				text = (
					(showFPS ? ("FPS: " + Math.floor(currentFPS) + "\n") : "") +
					(
						showMem && showMemPeak ? ("MEM / PEAK: " + CoolUtil.truncateFloat(currentMem) + " MB / " + CoolUtil.truncateFloat(currentMemPeak) + " MB\n") :
						showMem ? ("MEM: " + CoolUtil.truncateFloat(currentMem) + " MB\n") :
						showMemPeak ? ("MEM PEAK: " + CoolUtil.truncateFloat(currentMemPeak) + " MB\n") :
						""
					)
				);

				text += "\n";
			}
			
			if (inEditor) {
				y = (Lib.current.stage.stageHeight - 3) - (16 * ((showMem || showMemPeak) ? 2 : 1));
			}
			else {
				y = 3;
			}
		}
		else
			text = "\n";

		cacheCount = currentCount;
	}
	
	#if (windows || linux)
	#if windows
	@:functionCode("
		PROCESS_MEMORY_COUNTERS info;
		if (GetProcessMemoryInfo(GetCurrentProcess(), &info, sizeof(info)))
			return (size_t)info.WorkingSetSize;
		
		return 0;
	")
	#elseif linux
	@:functionCode('
		long rss = 0L;
		FILE* fp = NULL;
		if ( (fp = fopen( "/proc/self/statm", "r" )) == NULL )
			return (size_t)0L;      /* Cant open? */
		if ( fscanf( fp, "%*s%ld", &rss ) != 1 )
		{
			fclose( fp );
			return (size_t)0L;      /* Cant read? */
		}
		fclose( fp );
		return (size_t)rss * (size_t)sysconf( _SC_PAGESIZE);
	')
	#end
	public static function get_totalMemory():Int return 0;
	
	#if windows
	@:functionCode("
		PROCESS_MEMORY_COUNTERS info;
		if (GetProcessMemoryInfo(GetCurrentProcess(), &info, sizeof(info)))
			return (size_t)info.PeakWorkingSetSize;
		
		return 0;
	")
	#elseif linux
	@:functionCode("
		struct rusage rusage;
		getrusage(RUSAGE_SELF, &rusage);
		
		return (size_t)(rusage.ru_maxrss * 1024L);
	")
	#end
	public static function get_memPeak():Int return 0;
	#else
	public static function get_memPeak():Int return 0;
	
	public static function get_totalMemory():Int {
		return
			#if cpp
			Gc.memUsage()
			#elseif hl
			Gc.stats().totalAllocated
			#elseif (java || neko)
			Gc.stats().heap
			#end
		;
	}
	#end
}
