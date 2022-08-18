package openfl.display;

import haxe.Timer;
import openfl.events.Event;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.Lib;

#if (gl_stats && !disable_cffi && (!html5 || !canvas))
import openfl.display._internal.stats.Context3DStats;
import openfl.display._internal.stats.DrawCallContext;
#end

#if openfl
import openfl.system.System;
#end

#if cpp
import cpp.vm.Gc;
#elseif hl
import hl.Gc;
#elseif java
import java.vm.Gc;
#elseif neko
import neko.vm.Gc;
#end

// https://stackoverflow.com/questions/669438/how-to-get-memory-usage-at-runtime-using-c
#if windows
@:cppFileCode("
#include <windows.h>
#include <psapi.h>
")
#elseif linux
@:cppFileCode("
#include <unistd.h>
#include <sys/resource.h>

#include <stdio.h>
")
#elseif mac
@:cppFileCode("
#include <unistd.h>
#include <sys/resource.h>

#include <mach/mach.h>
")
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
	
	public var currentGcMem(default, null):Float;
	public var currentGcMemPeak(default, null):Float;
	
	public var showFPS:Bool = true;
	public var showMem:Bool = false;
	public var showMemPeak:Bool = false;
	public var showGLStats:Bool = false;
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
		defaultTextFormat = new TextFormat('assets/fonts/vcr.ttf', 16, color);

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
		var fps = (currentCount + cacheCount) / 2;
		currentFPS = Math.round(fps);
		//if (currentFPS > ClientPrefs.framerate) currentFPS = ClientPrefs.framerate;
		
		currentGcMem = Math.abs((get_gcMemory() / 1024) / 1000);
		if (currentGcMem > currentGcMemPeak) currentGcMemPeak = currentGcMem;
		#if (windows || linux)
		currentMem = Math.abs((get_totalMemory() / 1024) / 1000);
		var memPeak:Float = Math.abs((get_memPeak() / 1024) / 1000);
		if (memPeak > currentMemPeak) currentMemPeak = memPeak;
		if (currentMem > currentMemPeak) currentMemPeak = currentMem;
		#else
		currentMem = currentGcMem;
		currentMemPeak = currentGcMemPeak;
		#end

		if (canRender) {
			if (currentCount != cacheCount) {
				if (currentMem > 3000 || fps <= ClientPrefs.framerate / 2)
					textColor = 0xFFFF0000;
				else
					textColor = 0xFFFFFFFF;
				
				text = (
					(showFPS ? ("FPS: " + currentFPS + " (" + CoolUtil.truncateFloat((1 / fps) * 1000) + "ms)\n") : "") +
					(
						(
							showMem && showMemPeak ? ("MEM / PEAK: " + CoolUtil.truncateFloat(currentMem) + " MB / " + CoolUtil.truncateFloat(currentMemPeak) + " MB\n") :
							showMem ? ("MEM: " + CoolUtil.truncateFloat(currentMem) + " MB\n") :
							showMemPeak ? ("MEM PEAK: " + CoolUtil.truncateFloat(currentMemPeak) + " MB\n") :
							""
						)
						#if (windows || linux) + (
							showMem && showMemPeak ? ("GC MEM / PEAK: " + CoolUtil.truncateFloat(currentGcMem) + " MB / " + CoolUtil.truncateFloat(currentGcMemPeak) + " MB\n") :
							showMem ? ("GC MEM: " + CoolUtil.truncateFloat(currentGcMem) + " MB\n") :
							showMemPeak ? ("GC MEM PEAK: " + CoolUtil.truncateFloat(currentGcMemPeak) + " MB\n") :
							""
						)
						#end
					) +
					(
						showGLStats ?
						(
							#if (gl_stats && !disable_cffi && (!html5 || !canvas))
							"DRAWS: " + Context3DStats.totalDrawCalls() + "\n"
							#else
							"DRAWS: 0\n"
							#end
						)
						: ""
					)
				);

				text += "\n";
			}
			
			if (inEditor) {
				y = (Lib.current.stage.stageHeight - 3) - (
					16 *
					(
						(showFPS ? 1 : 0) +
						((showMem || showMemPeak) ? #if (windows || linux) 2 #else 1 #end : 0) +
						(showGLStats ? 1 : 0)
					)
				);
			}
			else {
				y = 3;
			}
		}
		else
			text = "\n";

		cacheCount = currentCount;
	}
	
	public static function get_gcMemory():Int {
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
	
	#if (windows || linux)
	#if windows
	@:functionCode("
		PROCESS_MEMORY_COUNTERS info;
		if (GetProcessMemoryInfo(GetCurrentProcess(), &info, sizeof(info)))
			return (size_t)info.WorkingSetSize;
	")
	#elseif linux
	@:functionCode('
		long rss = 0L;
		FILE* fp = NULL;
		
		if ((fp = fopen("/proc/self/statm", "r")) == NULL)
			return (size_t)0L;
		
		fclose(fp);
		if (fscanf(fp, "%*s%ld", &rss) == 1)
			return (size_t)rss * (size_t)sysconf( _SC_PAGESIZE);
	')
	#elseif mac
	@:functionCode("
		struct mach_task_basic_info info;
		mach_msg_type_number_t infoCount = MACH_TASK_BASIC_INFO_COUNT;
		
		if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &infoCount) == KERN_SUCCESS)
			return (size_t)info.resident_size;
	")
	#end
	public static function get_totalMemory():Int return 0;
	
	#if windows
	@:functionCode("
		PROCESS_MEMORY_COUNTERS info;
		if (GetProcessMemoryInfo(GetCurrentProcess(), &info, sizeof(info)))
			return (size_t)info.PeakWorkingSetSize;
	")
	#elseif linux
	@:functionCode("
		struct rusage rusage;
		getrusage(RUSAGE_SELF, &rusage);
		
		if (true)
			return (size_t)(rusage.ru_maxrss * 1024L);
	")
	#elseif mac
	@:functionCode("
		struct rusage rusage;
		getrusage(RUSAGE_SELF, &rusage);
		
		if (true)
			return (size_t)rusage.ru_maxrss;
	")
	#end
	public static function get_memPeak():Int return 0;
	#else
	public static function get_memPeak():Int return 0;
	
	inline public static function get_totalMemory():Int return get_gcMemory();
	#end
}
