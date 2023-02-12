package lime._internal.backend.native;

import haxe.Timer;
import haxe.Int64;

import lime.math.Vector4;
import lime.media.openal.AL;
import lime.media.openal.ALBuffer;
import lime.media.openal.ALSource;
import lime.media.vorbis.VorbisFile;
import lime.media.AudioBuffer;
import lime.media.AudioSource;
import lime.utils.UInt8Array;

#if !lime_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
@:access(lime.media.AudioBuffer)
class NativeAudioSource {
	private static var STREAM_BUFFER_SIZE:Int = 16000;
	//#if (native_audio_buffers && !macro)
	//private static var STREAM_NUM_BUFFERS:Int = Std.parseInt(haxe.macro.Compiler.getDefine("native_audio_buffers"));
	//#else
	private static var STREAM_NUM_BUFFERS:Int = 9;
	//#end
	private static var STREAM_TIMER_FREQUENCY:Int = 100;

	private var buffers:Array<ALBuffer>;
	private var bufferDatas:Array<UInt8Array>;
	private var bufferTimeBlocks:Array<Float>;
	private var bufferLoops:Int;
	private var queuedBuffers:Int;
	private var canFill:Bool;

	private var length:Null<Int>;
	private var loopTime:Null<Int>;
	private var playing:Bool;
	private var loops:Int;
	private var position:Vector4;

	private var dataLength:Int;
	private var samples:Int;
	private var format:Int;
	private var completed:Bool;
	private var stream:Bool;

	private var handle:ALSource;
	private var parent:AudioSource;
	private var timer:Timer;
	private var streamTimer:Timer;

	public function new(parent:AudioSource) {
		this.parent = parent;
		position = new Vector4();
	}

	public function dispose():Void {
		if (handle != null) {
			AL.sourcei(handle, AL.BUFFER, null);
			AL.deleteSource(handle);
			handle = null;
		}

		if (buffers != null) {
			AL.deleteBuffers(buffers);
			buffers = null;
		}
	}

	public function init():Void {
		parent.buffer.initBuffer();

		handle = AL.createSource();
		format = parent.buffer.__format;
		bufferLoops = 0;

		var vorbisFile = parent.buffer.__srcVorbisFile;
		if (stream = vorbisFile != null) {
			dataLength = Std.int(Int64.toInt(vorbisFile.pcmTotal()) * parent.buffer.channels * (parent.buffer.bitsPerSample / 8));

			buffers = new Array();
			bufferDatas = new Array();
			bufferTimeBlocks = new Array();
			for (i in 0...STREAM_NUM_BUFFERS) {
				buffers.push(AL.createBuffer());
				bufferDatas.push(new UInt8Array(STREAM_BUFFER_SIZE));
				bufferTimeBlocks.push(0);
			}
		}
		else {
			dataLength = parent.buffer.data.length;
			if (handle != null) AL.sourcei(handle, AL.BUFFER, parent.buffer.__srcBuffer);
		}

		samples = Std.int((dataLength * 8) / (parent.buffer.channels * parent.buffer.bitsPerSample));
	}

	public function play():Void {
		if (playing || handle == null) return;

		playing = true;
		setCurrentTime(completed ? 0 : getCurrentTime());
	}

	public function pause():Void {
		if (handle != null) AL.sourcePause(handle);

		playing = false;
		stopStreamTimer();
		stopTimer();
	}

	public function stop():Void {
		if (playing && handle != null && AL.getSourcei(handle, AL.SOURCE_STATE) == AL.PLAYING)
			AL.sourceStop(handle);

		bufferLoops = 0;

		playing = false;
		stopStreamTimer();
		stopTimer();
	}

	private function complete():Void {
		stop();

		completed = true;
		parent.onComplete.dispatch();
	}

	private function readVorbisFileBuffer(vorbisFile:VorbisFile, length:Int):UInt8Array {
		#if lime_vorbis
		var buffer = bufferDatas[0], read = STREAM_NUM_BUFFERS - 1, total = 0, readMax;
		for (i in (STREAM_NUM_BUFFERS - queuedBuffers)...read) {
			bufferTimeBlocks[i] = bufferTimeBlocks[i + 1];
			bufferDatas[i] = bufferDatas[i + 1];
		}
		bufferTimeBlocks[read] = vorbisFile.timeTell();
		bufferDatas[read] = buffer;

		while(total < length) {
			if ((readMax = 4096) > (read = length - total)) readMax = read;
			if ((read = vorbisFile.read(buffer.buffer, total, readMax)) > 0) total += read;
			else if (loops > 0) {
				bufferLoops++;
				vorbisFile.timeSeek(loopTime != null ? Math.max(0, loopTime / 1000) : 0);
			}
			else 
				break;
		}
		return buffer;
		#else
		return null;
		#end
	}

	private function fillBuffers(buffers:Array<ALBuffer>):Void {
		#if lime_vorbis
		if (buffers.length < 1 || parent == null || parent.buffer == null) return dispose();

		var vorbisFile = parent.buffer.__srcVorbisFile;
		if (vorbisFile == null) return dispose();

		var position = Int64.toInt(vorbisFile.pcmTell()), samples = samples, sampleRate = parent.buffer.sampleRate;
		if (length != null) samples = Std.int((length + parent.offset) / 1000 * sampleRate);
		if (position >= samples) return;

		var numBuffers = 0, size = 0, data;
		for (buffer in buffers) {
			if (samples - position < 1)
				break;

			size = (data = readVorbisFileBuffer(vorbisFile, STREAM_BUFFER_SIZE)).length;
			AL.bufferData(buffer, format, data, size, sampleRate);
			numBuffers++;
		}

		AL.sourceQueueBuffers(handle, numBuffers, buffers);

		if (playing && AL.getSourcei(handle, AL.SOURCE_STATE) == AL.STOPPED) {
			AL.sourcePlay(handle);
			resetTimer(Std.int((getLength() - getCurrentTime()) / getPitch()));
		}
		#end
	}

	// Timers
	inline function stopStreamTimer():Void if (streamTimer != null) streamTimer.stop();

	private function resetStreamTimer():Void {
		stopStreamTimer();

		streamTimer = new Timer(STREAM_TIMER_FREQUENCY);
		streamTimer.run = streamTimer_onRun;
	}

	inline function stopTimer():Void if (timer != null) timer.stop();

	private function resetTimer(timeRemaining:Int):Void {
		stopTimer();

		if (timeRemaining <= 30) {
			timer_onRun();
			return;
		}
		timer = new Timer(timeRemaining);
		timer.run = timer_onRun;
	}

	// Event Handlers
	private function streamTimer_onRun():Void {
		var vorbisFile;
		if (handle == null || (vorbisFile = parent.buffer.__srcVorbisFile) == null) return;

		var processed = AL.getSourcei(handle, AL.BUFFERS_PROCESSED);
		if (processed > 0) {
			if ((canFill = !canFill) && queuedBuffers < STREAM_NUM_BUFFERS) fillBuffers([buffers[++queuedBuffers - 1]]);
			fillBuffers(AL.sourceUnqueueBuffers(handle, processed));
		}
	}

	private function timer_onRun():Void {
		if (playing && bufferLoops <= 0) {
			var timeRemaining = Std.int((getLength() - getCurrentTime()) / getPitch());
			if (timeRemaining > 100 && AL.getSourcei(handle, AL.SOURCE_STATE) == AL.PLAYING) {
				resetTimer(timeRemaining);
				return;
			}
		}

		if (loops <= 0) {
			complete();
			return;
		}

		if (bufferLoops > 0) {
			loops -= bufferLoops;
			bufferLoops = 0;
			parent.onLoop.dispatch();
			return;
		}

		loops--;
		setCurrentTime(loopTime != null ? Std.int(Math.max(0, loopTime)) : 0);
		parent.onLoop.dispatch();
	}

	// Get & Set Methods
	public function getCurrentTime():Int {
		if (completed) return getLength();
		else if (handle != null) {
			var time;

			if (stream) time = Std.int((bufferTimeBlocks[STREAM_NUM_BUFFERS - queuedBuffers] + AL.getSourcef(handle, AL.SEC_OFFSET)) * 1000);
			else time = Std.int(samples / parent.buffer.sampleRate * (AL.getSourcei(handle, AL.BYTE_OFFSET) / dataLength) * 1000);
			time -= parent.offset;

			if (time > 0) return time;
		}
		return 0;
	}

	public function setCurrentTime(value:Int):Int {
		if (handle == null) return value;

		var total = samples / parent.buffer.sampleRate * 1000;
		var time = Math.max(0, Math.min(total, value + parent.offset)), ratio = time / total;

		if (stream) {
			AL.sourceStop(handle);

			// uses the al queuedbuffers instead if there is any unexpected repeated buffers
			AL.sourceUnqueueBuffers(handle, AL.getSourcei(handle, AL.BUFFERS_QUEUED));

			#if lime_vorbis
			var vorbisFile = parent.buffer.__srcVorbisFile;
			if (vorbisFile != null) {
				vorbisFile.timeSeek(time / 1000);
				//AL.sourcei(handle, AL.BYTE_OFFSET, Std.int(dataLength * (
				//	ratio - (Math.floor(samples * ratio / STREAM_BUFFER_SIZE) * STREAM_BUFFER_SIZE / samples)
				//)));

				canFill = true;
				fillBuffers(buffers.slice(0, queuedBuffers = 3));
				if (playing) resetStreamTimer();
			}
			#end
		}
		else {
			AL.sourceRewind(handle);
			AL.sourcei(handle, AL.BYTE_OFFSET, Std.int(dataLength * ratio));
		}

		if (playing) {
			var timeRemaining = Std.int((getLength() - value) / getPitch());
			if (completed = timeRemaining < 1) complete();
			else {
				AL.sourcePlay(handle);
				resetTimer(timeRemaining);
			}
		}
		return value;
	}

	public function getLength():Int {
		if (length != null) return length;
		return Std.int(samples / parent.buffer.sampleRate * 1000) - parent.offset;
	}
	public function setLength(value:Int):Int {
		if (value == length) return value;
		if (playing) {
			var timeRemaining = Std.int((value - getCurrentTime()) / getPitch());
			if (timeRemaining > 0) resetTimer(timeRemaining);
		}
		return length = value;
	}

	public function getPitch():Float {
		if (handle != null) return AL.getSourcef(handle, AL.PITCH);
		return 1;
	}

	public function setPitch(value:Float):Float {
		if (handle == null || value == getPitch()) return value;
		AL.sourcef(handle, AL.PITCH, value);

		if (playing) {
			var timeRemaining = Std.int((getLength() - getCurrentTime()) / value);
			if (timeRemaining > 0) resetTimer(timeRemaining);
		}
		return value;
	}

	public function getGain():Float {
		if (handle == null) return 1;
		return AL.getSourcef(handle, AL.GAIN);
	}

	public function setGain(value:Float):Float {
		if (handle != null) AL.sourcef(handle, AL.GAIN, value);
		return value;
	}

	inline public function getLoops():Int return loops;

	inline public function setLoops(value:Int):Int return loops = value;

	inline public function getLoopTime():Int return loopTime;

	inline public function setLoopTime(value:Int):Int return loopTime = value;

	#if emscripten
	inline public function getPosition():Vector4 return position;
	#else
	public function getPosition():Vector4 {
		if (handle != null) {
			var value = AL.getSource3f(handle, AL.POSITION);
			position.x = value[0];
			position.y = value[1];
			position.z = value[2];
		}
		return position;
	}
	#end

	public function setPosition(value:Vector4):Vector4 {
		position.x = value.x;
		position.y = value.y;
		position.z = value.z;
		position.w = value.w;

		if (handle != null) {
			AL.distanceModel(AL.NONE);
			AL.source3f(handle, AL.POSITION, position.x, position.y, position.z);
		}
		return position;
	}
}