package lime._internal.backend.native;

import haxe.io.Bytes;
import haxe.Int64;
import haxe.Timer;
import lime.math.Vector4;
import lime.media.openal.AL;
import lime.media.openal.ALBuffer;
import lime.media.openal.ALSource;
import lime.media.vorbis.VorbisFile;
import lime.media.AudioManager;
import lime.media.AudioSource;
import lime.utils.UInt8Array;

#if !lime_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
@:access(lime.media.AudioBuffer)
class NativeAudioSource
{
	private static var STREAM_BUFFER_SIZE = 48000;
	#if (native_audio_buffers && !macro)
	private static var STREAM_NUM_BUFFERS = Std.parseInt(haxe.macro.Compiler.getDefine("native_audio_buffers"));
	#else
	private static var STREAM_NUM_BUFFERS = 3;
	#end
	private static var STREAM_TIMER_FREQUENCY = 100;

	private var buffers:Array<ALBuffer>;
	private var bufferDatas:Array<UInt8Array>;
	private var bufferTimeBlocks:Array<Float>;
	private var emptyBufferData:UInt8Array;
	private var completed:Bool;
	private var dataLength:Int;
	private var format:Int;
	private var handle:ALSource;
	private var length:Null<Int>;
	private var loops:Int;
	private var loopTime:Null<Int>;
	private var parent:AudioSource;
	private var playing:Bool;
	private var position:Vector4;
	private var samples:Int;
	private var stream:Bool;
	private var streamTimer:Timer;
	private var timer:Timer;

	public function new(parent:AudioSource) {
		this.parent = parent;

		position = new Vector4();
	}

	public function dispose():Void {
		forceStop();

		if (handle != null) {
			AL.sourcei(handle, AL.BUFFER, null);
			AL.deleteSource(handle);

			if (buffers != null) {
				AL.deleteBuffers(buffers);
				buffers = null;
			}
			bufferDatas = null;
			bufferTimeBlocks = null;
			emptyBufferData = null;
			handle = null;
		}
	}

	public function init():Void {
		parent.buffer.initBuffer();

		dataLength = 0;
		format = parent.buffer.__format;

		if (parent.buffer.__srcVorbisFile != null) {
			stream = true;

			var vorbisFile = parent.buffer.__srcVorbisFile;
			dataLength = Std.int(Int64.toInt(vorbisFile.pcmTotal()) * parent.buffer.channels * (parent.buffer.bitsPerSample / 8));

			buffers = new Array();
			bufferDatas = new Array();
			bufferTimeBlocks = new Array();
			emptyBufferData = new UInt8Array(STREAM_BUFFER_SIZE);

			for (i in 0...STREAM_NUM_BUFFERS) {
				buffers.push(AL.createBuffer());
				bufferDatas.push(new UInt8Array(STREAM_BUFFER_SIZE));
				bufferTimeBlocks.push(0);
			}

			handle = AL.createSource();
		}
		else {
			dataLength = parent.buffer.data.length;

			handle = AL.createSource();

			if (handle != null)
				AL.sourcei(handle, AL.BUFFER, parent.buffer.__srcBuffer);
		}

		samples = Std.int((dataLength * 8) / (parent.buffer.channels * parent.buffer.bitsPerSample));
	}

	private var noReFillBuffer:Bool = false;
	public function play():Void {
		/*var pitch:Float = AL.getSourcef (handle, AL.PITCH);
			trace(pitch);
			AL.sourcef (handle, AL.PITCH, pitch*0.9);
			pitch = AL.getSourcef (handle, AL.PITCH);
			trace(pitch); */
		/*var pos = getPosition();
			trace(AL.DISTANCE_MODEL);
			AL.distanceModel(AL.INVERSE_DISTANCE);
			trace(AL.DISTANCE_MODEL);
			AL.sourcef(handle, AL.ROLLOFF_FACTOR, 5);
			setPosition(new Vector4(10, 10, -100));
			pos = getPosition();
			trace(pos); */
		/*var filter = AL.createFilter();
			trace(AL.getErrorString());

			AL.filteri(filter, AL.FILTER_TYPE, AL.FILTER_LOWPASS);
			trace(AL.getErrorString());

			AL.filterf(filter, AL.LOWPASS_GAIN, 0.5);
			trace(AL.getErrorString());

			AL.filterf(filter, AL.LOWPASS_GAINHF, 0.5);
			trace(AL.getErrorString());

			AL.sourcei(handle, AL.DIRECT_FILTER, filter);
			trace(AL.getErrorString()); */

		if (playing || handle == null)
			return;

		playing = true;

		setCurrentTime(completed ? 0 : getCurrentTime());
		if (stream) resetStreamTimer();
	}

	public function pause():Void {
		playing = false;

		if (handle == null) return;
		AL.sourcePause(handle);
		noReFillBuffer = true;

		stopStreamTimer();
		stopTimer();
	}

	private function readVorbisFileBuffer(vorbisFile:VorbisFile, length:Int):UInt8Array {
		#if lime_vorbis
		var buffer = bufferDatas[0];
		var read = STREAM_NUM_BUFFERS - 1, total = 0, readMax;

		for (i in 0...read) {
			bufferTimeBlocks[i] = bufferTimeBlocks[i + 1];
			bufferDatas[i] = bufferDatas[i + 1];
		}
		bufferTimeBlocks[read] = vorbisFile.timeTell();
		bufferDatas[read] = buffer;

		while(total < length) {
			if ((readMax = 4096) > (read = length - total)) readMax = read;
			if ((read = vorbisFile.read(buffer.buffer, total, readMax)) > 0)
				total += read;
			else
				break;
		}

		return buffer;
		#else
		return null;
		#end
	}

	private var bufferLoopedTimes:Array<Float> = [];
	private function refillBuffers(buffers:Array<ALBuffer> = null):Void {
		#if lime_vorbis
		if (handle == null || parent == null || parent.buffer == null) return dispose();

		var vorbisFile = parent.buffer.__srcVorbisFile;
		if (vorbisFile == null) return dispose();

		var position = 0, samples = samples, sampleRate = parent.buffer.sampleRate;
		if (buffers == null) {
			var buffersProcessed:Int = AL.getSourcei(handle, AL.BUFFERS_PROCESSED);
			if (buffersProcessed < 1) return;

			if (length != null) samples = Std.int((length + parent.offset) / 1000 * sampleRate);
			if ((position = Int64.toInt(vorbisFile.pcmTell())) >= samples) {	
				if (loops - bufferLoopedTimes.length < 1) return;
				var st:Null<Float> = loopTime;
				if (st == null || st < 1) st = 0;
				else bufferLoopedTimes.push(st = st / 1000);

				vorbisFile.timeSeek(st);
				position = Std.int(st * sampleRate);
			}
			buffers = AL.sourceUnqueueBuffers(handle, buffersProcessed);
		}
		else {
			if (buffers.length == 0) return;

			position = Int64.toInt(vorbisFile.pcmTell());
			if (length != null) samples = Std.int((length + parent.offset) / 1000 * sampleRate);
		}

		if (position < 0) vorbisFile.timeSeek(0);

		var numBuffers = 0, size = 0, data;
		for (buffer in buffers) {
			if ((size = samples - position) < STREAM_BUFFER_SIZE) {
				if (size < 1) break;
			}

			data = readVorbisFileBuffer(vorbisFile, STREAM_BUFFER_SIZE);
			AL.bufferData(buffer, format, data, STREAM_BUFFER_SIZE, sampleRate);
			position += STREAM_BUFFER_SIZE;
			numBuffers++;
		}

		AL.sourceQueueBuffers(handle, numBuffers, buffers);

		// OpenAL can unexpectedly stop playback if the buffers run out
		// of data, which typically happens if an operation (such as
		// resizing a window) freezes the main thread.
		// If AL is supposed to be playing but isn't, restart it here.
		if (playing && AL.getSourcei(handle, AL.SOURCE_STATE) == AL.STOPPED) {
			AL.sourcePlay(handle);
			resetTimer(Std.int((getLength() - getCurrentTime()) / getPitch()));
		}
		#end
	}

	public function stop():Void {
		if (playing && handle != null && AL.getSourcei(handle, AL.SOURCE_STATE) == AL.PLAYING)
			AL.sourceStop(handle);

		playing = false;
		noReFillBuffer = false;
		bufferLoopedTimes.resize(0);

		stopTimer();
		stopStreamTimer();
		setCurrentTime(0);
	}

	private function forceStop():Void {
		stop();

		completed = true;
		parent.onComplete.dispatch();
	}

	private function stopStreamTimer():Void {
		if (streamTimer != null)
			streamTimer.stop();
	}

	private function resetStreamTimer():Void {
		stopStreamTimer();

		if (stream) {
			streamTimer = new Timer(STREAM_TIMER_FREQUENCY);
			streamTimer.run = streamTimer_onRun;
		}
	}

	private function stopTimer():Void {
		if (timer != null)
			timer.stop();
	}

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
		refillBuffers();
	}

	private function timer_onRun():Void {
		if (handle == null) return forceStop();

		var check = !stream, curTime = 0;
		if (!check && bufferLoopedTimes.length > 0) {
			var offset:Float = AL.getSourcef(handle, AL.SEC_OFFSET) * 1000, index = Math.floor(offset / STREAM_BUFFER_SIZE);
			if (index >= STREAM_NUM_BUFFERS || bufferTimeBlocks[index] != bufferLoopedTimes[0]) {
				curTime = (Std.int(bufferTimeBlocks[0] * 1000) + Std.int(offset)) - parent.offset;
				check = true;
			}
		}
		else {
			curTime = getCurrentTime();
			check = true;
		}

		if (check) {
			var timeRemaining = Std.int(Math.max(31, (getLength() - curTime) / getPitch()));
			if (bufferLoopedTimes.length > 0 || (timeRemaining > 100 && AL.getSourcei(handle, AL.SOURCE_STATE) == AL.PLAYING)) {
				resetTimer(timeRemaining);
				return;
			}
		}

		if (loops > 0) {
			var st = loopTime;
			if (st == null || st < 1) st = 0;

			if (stream && bufferLoopedTimes.length > 0) {
				bufferLoopedTimes.shift();
				loops--;
				resetTimer(Std.int((getLength() - st) / getPitch()));
				parent.onLoop.dispatch();
				return;
			}

			loops--;
			playing = true;
			setCurrentTime(st);
			parent.onLoop.dispatch();
			return;
		}

		forceStop();
	}

	// Get & Set Methods
	public function getCurrentTime():Int {
		if (completed) return getLength();
		else if (handle != null) {
			if (stream) {
				var time = (Std.int(bufferTimeBlocks[0] * 1000) + Std.int(AL.getSourcef(handle, AL.SEC_OFFSET) * 1000)) - parent.offset;
				if (time < 0) return 0;
				return time;
			}
			else {
				var offset = AL.getSourcei(handle, AL.BYTE_OFFSET);
				var ratio = (offset / dataLength);
				var totalSeconds = samples / parent.buffer.sampleRate;

				var time = Std.int(totalSeconds * ratio * 1000) - parent.offset;

				// var time = Std.int (AL.getSourcef (handle, AL.SEC_OFFSET) * 1000) - parent.offset;
				if (time < 0) return 0;
				return time;
			}
		}

		return 0;
	}

	public function setCurrentTime(value:Int):Int {
		// `setCurrentTime()` has side effects and is never safe to skip.
		/* if (value == getCurrentTime())
			return value;
		*/

		if (handle != null && parent != null && parent.buffer != null) {
			if (stream) {
				AL.sourceStop(handle);

				if (parent.buffer.__srcVorbisFile != null)
					parent.buffer.__srcVorbisFile.timeSeek((value + parent.offset) / 1000);

				if (playing || Std.int(bufferTimeBlocks[0] * 1000) != Std.int(value + parent.offset)) {
					AL.sourceUnqueueBuffers(handle, STREAM_NUM_BUFFERS);
					refillBuffers(buffers);
					noReFillBuffer = false;
				}

				if (playing) AL.sourcePlay(handle);
			}
			else {
				AL.sourceRewind(handle);

				// AL.sourcef (handle, AL.SEC_OFFSET, (value + parent.offset) / 1000);

				var secondOffset = (value + parent.offset) / 1000;
				var totalSeconds = samples / parent.buffer.sampleRate;

				if (secondOffset < 0) secondOffset = 0;
				if (secondOffset > totalSeconds) secondOffset = totalSeconds;

				var ratio = (secondOffset / totalSeconds);
				var totalOffset = Std.int(dataLength * ratio);

				AL.sourcei(handle, AL.BYTE_OFFSET, totalOffset);
				if (playing) AL.sourcePlay(handle);
			}
		}

		if (playing) {
			var timeRemaining = Std.int((getLength() - value) / getPitch());

			if (timeRemaining > 0) {
				completed = false;
				resetTimer(timeRemaining);
			}
			else {
				playing = false;
				completed = true;
			}
		}

		return value;
	}

	public function getGain():Float {
		if (handle != null)
			return AL.getSourcef(handle, AL.GAIN);
		else
			return 1;
	}

	public function setGain(value:Float):Float {
		if (handle != null)
			AL.sourcef(handle, AL.GAIN, value);

		return value;
	}

	public function getLength():Int {
		if (length != null)
			return length;

		return Std.int(samples / parent.buffer.sampleRate * 1000) - parent.offset;
	}

	public function setLength(value:Int):Int {
		if (value == length) return value;

		if (playing) {
			var timeRemaining = Std.int((value - getCurrentTime()) / getPitch());
			if (timeRemaining > 0)
				resetTimer(timeRemaining);
		}

		return length = value;
	}

	public function getLoops():Int {
		return loops;
	}

	public function setLoops(value:Int):Int {
		return loops = value;
	}

	public function getLoopTime():Int {
		return loopTime;
	}

	public function setLoopTime(value:Int):Int {
		return loopTime = value;
	}

	public function getPitch():Float {
		if (handle != null)
			return AL.getSourcef(handle, AL.PITCH);
		else
			return 1;
	}

	public function setPitch(value:Float):Float {
		if (value == getPitch()) return value;

		if (playing) {
			var timeRemaining = Std.int((getLength() - getCurrentTime()) / value);
			if (timeRemaining > 0)
				resetTimer(timeRemaining);
		}

		if (handle != null)
			AL.sourcef(handle, AL.PITCH, value);

		return value;
	}

	public function getPosition():Vector4 {
		if (handle != null) {
			#if !emscripten
			var value = AL.getSource3f(handle, AL.POSITION);
			position.x = value[0];
			position.y = value[1];
			position.z = value[2];
			#end
		}

		return position;
	}

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
