package openfl.display;

import haxe.Timer;
import haxe.Int64;
import openfl.display.BlendMode;
import openfl.events.Event;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.Lib;

#if (gl_stats && !disable_cffi && (!html5 || !canvas))
import openfl.display._internal.stats.Context3DStats;
import openfl.display._internal.stats.DrawCallContext;
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
class FPS extends TextField {
	public var currentFPS(default, null):Int;
	public var currentMem(default, null):Float;
	public var currentMemPeak(default, null):Float;

	public var currentGcMem(default, null):Float;
	public var currentGcMemPeak(default, null):Float;

	public var showFPS:Bool = true;
	public var showMem:Bool = false;
	public var showMemPeak:Bool = false;
	public var showGc:Bool = false;
	public var showGLStats:Bool = false;
	public var inEditor:Bool = false;

	public var borderSize:Int = 1;

	// Border Original Codes by @sayofthelor, i just did some clean-up and patches thats all :P
	@:noCompletion private final borders:Array<TextField> = new Array<TextField>();

	@:noCompletion private var cacheCount:Int;
	@:noCompletion private var currentTime:Float;
	@:noCompletion private var times:Array<Float>;

	public function new(x:Float = 3, y:Float = 3, color:Int = 0, showFPS:Bool = true, showMem:Bool = false) {
		super();

		var border:TextField;
		for (i in 0...8) {
			borders.push(border = new TextField());
			border.selectable = false;
			border.mouseEnabled = false;
			border.autoSize = LEFT;
			border.multiline = true;
			border.width = 800;
			border.height = 70;
		}

		this.x = x;
		this.y = y;

		selectable = false;
		mouseEnabled = false;

		defaultTextFormat = new TextFormat('assets/fonts/vcr.ttf', 14, color);
		autoSize = LEFT;
		multiline = true;
		width = 800;
		height = 70;

		currentFPS = 0;
		currentMem = 0;
		currentMemPeak = 0;

		cacheCount = 0;
		currentTime = 0;
		times = [];

		#if flash
		addEventListener(Event.ENTER_FRAME, function(_) {
			__enterFrame(Lib.getTimer());
		});
		#end
		addEventListener(Event.REMOVED, function(_) {
			for (border in borders) this.parent.removeChild(border);
		});
		addEventListener(Event.ADDED, function(_) {
			for (border in borders) this.parent.addChildAt(border, this.parent.getChildIndex(this));
		});
	}

	@:noCompletion override function set_visible(value:Bool):Bool {
		for (border in borders) border.visible = value;
		return super.set_visible(value);
	}

	@:noCompletion override function set_defaultTextFormat(value:TextFormat):TextFormat {
		for (border in borders) {
			border.defaultTextFormat = value;
			border.textColor = 0xFF000000;
		}
		return super.set_defaultTextFormat(value);
	}

	@:noCompletion override function set_x(x:Float):Float {
		for (i in 0...8) borders[i].x = x + ([0, 3, 5].contains(i) ? borderSize : [2, 4, 7].contains(i) ? -borderSize : 0);
		return super.set_x(x);
	}

	@:noCompletion override function set_y(y:Float):Float {
		for (i in 0...8) borders[i].y = y + ([0, 1, 2].contains(i) ? borderSize : [5, 6, 7].contains(i) ? -borderSize : 0);
		return super.set_y(y);
	}

	@:noCompletion override function set_text(text:String):String {
		for (border in borders) border.text = text;
		return super.set_text(text);
	}

	@:noCompletion
	#if flash
	private function __enterFrame(time:Float):Void {
		currentTime = time;
	#else
	private override function __enterFrame(deltaTime:Float):Void {
		currentTime = Timer.stamp();
	#end
		times.push(currentTime);

		while (times[0] < currentTime - #if flash 1000 #else 1 #end)
			times.shift();

		var currentCount = times.length;
		var fps = currentCount;//(currentCount + cacheCount) / 2;
		currentFPS = Math.round(fps);

		if (!visible || !(showFPS || showMem || showMemPeak)) {
			if (text != '') text = '';
			cacheCount = currentCount;
			return;
		}
		if (currentCount == cacheCount) {
			cacheCount = currentCount;
			return;
		}

		currentGcMem = cast(Int64.make(0, get_gcMemory()), Float) / 0x400 / 0x400;
		if (currentGcMem > currentGcMemPeak) currentGcMemPeak = currentGcMem;
		#if (windows || linux || mac)
		currentMem = cast(Int64.make(0, get_totalMemory()), Float) / 0x400 / 0x400;
		var memPeak:Float = cast(Int64.make(0, get_memPeak()), Float) / 0x400 / 0x400;
		if (memPeak > currentMemPeak) currentMemPeak = memPeak;
		if (currentMem > currentMemPeak) currentMemPeak = currentMem;
		#else
		currentMem = currentGcMem;
		currentMemPeak = currentGcMemPeak;
		#end

		if (currentMem > 2000 || fps <= ClientPrefs.framerate / 2) textColor = 0xFFFF0000;
		else textColor = 0xFFFFFFFF;

		// This looks shit... T᎔T
		text = (
			(showFPS ? ('FPS: ${currentFPS}' + #if !flash ' | ' + Math.round(1000 / deltaTime) + #end ' (${CoolUtil.truncateFloat((1 / currentCount) * 1000)}ms)\n') : "") +
			(
				(
					showMem && showMemPeak ? ('MEM / PEAK: ${CoolUtil.truncateFloat(currentMem)} MB / ${CoolUtil.truncateFloat(currentMemPeak)} MB\n') :
					showMem ? ('MEM: ${CoolUtil.truncateFloat(currentMem)} MB\n') :
					showMemPeak ? ('MEM PEAK: ${CoolUtil.truncateFloat(currentMemPeak)} MB\n') :
					""
				)
				#if (windows || linux || mac) + (
					showGc ? (
						showMem && showMemPeak ? ('GC MEM / PEAK: ${CoolUtil.truncateFloat(currentGcMem)} MB / ${CoolUtil.truncateFloat(currentGcMemPeak)} MB\n') :
						showMem ? ('GC MEM: ${CoolUtil.truncateFloat(currentGcMem)} MB\n') :
						showMemPeak ? ('GC MEM PEAK: ${CoolUtil.truncateFloat(currentGcMemPeak)} MB\n') :
						""
					) :
					""
				)
				#end
			) +
			(
				showGLStats ?
				(
					#if (gl_stats && !disable_cffi && (!html5 || !canvas))
					'DRAWS: ${Context3DStats.totalDrawCalls()}\n'
					#else
					'DRAWS: unknown\n'
					#end
				)
				: ""
			)
		);

		if (inEditor) {
			y = (Lib.current.stage.stageHeight - 3) - (
				16 *
				(
					(showFPS ? 1 : 0) +
					((showMem || showMemPeak) ? (#if (windows || linux || mac)showGc ? 2 :#end 1) : 0) +
					(showGLStats ? 1 : 0)
				)
			);
		}
		else
			y = 3;
	}

	public static function get_gcMemory():Int {
		return
			#if cpp
			untyped __global__.__hxcpp_gc_used_bytes()
			#elseif hl
			Gc.stats().totalAllocated
			#elseif (java || neko)
			Gc.stats().heap
			#elseif (js && html5)
			untyped #if haxe4 js.Syntax.code #else __js__ #end ("(window.performance && window.performance.memory) ? window.performance.memory.usedJSHeapSize : 0")
			#end
		;
	}
	
	#if (windows || linux || mac)
	#if windows
	@:functionCode("
		PROCESS_MEMORY_COUNTERS info;
		if (GetProcessMemoryInfo(GetCurrentProcess(), &info, sizeof(info)))
			return (size_t)info.WorkingSetSize;
	")
	#elseif linux
	@:functionCode("
		long rss = 0L;
		FILE* fp = NULL;
		
		if ((fp = fopen(\"/proc/self/statm\", \"r\")) == NULL)
			return (size_t)0L;
		
		fclose(fp);
		if (fscanf(fp, \"%*s%ld\", &rss) == 1)
			return (size_t)rss * (size_t)sysconf( _SC_PAGESIZE);
	")
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
	inline public static function get_memPeak():Int return currentMemPeak;
	
	inline public static function get_totalMemory():Int return get_gcMemory();
	#end
}
