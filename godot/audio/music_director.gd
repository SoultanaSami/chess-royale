class_name MusicDirector
extends Node
## Crossfades the violin-led menu score and the quieter tactical match cue.

const TRACKS := {
	"library": "res://audio/music/ashen_crown.ogg",
	"battle": "res://audio/music/battle_theme.wav",
}
const CUE_VOLUME_DB := {"library": -3.0, "battle": -11.0}
const SILENCE_DB := -48.0
const FADE_SECONDS := 0.9

var current_cue := ""
var _players: Array[AudioStreamPlayer] = []
var _active_index := -1
var _fades: Array[Tween] = []
var _streams: Dictionary = {}


func _ready() -> void:
	_fades.resize(2)
	for _index in range(2):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		player.volume_db = SILENCE_DB
		add_child(player)
		_players.append(player)


func play_cue(cue: String) -> void:
	if not TRACKS.has(cue):
		push_warning("Unknown music cue: %s" % cue)
		return
	if cue == current_cue and _active_index >= 0 and _players[_active_index].playing:
		return

	var next_index := 0 if _active_index != 0 else 1
	var next_player := _players[next_index]
	var stream := _load_stream(cue)
	if stream == null:
		push_error("Could not load music cue: %s" % TRACKS[cue])
		return
	# A player can be reused before its old fade-out has finished. Cancel its
	# pending stop callback as well, otherwise quick menu changes silence it.
	for fade in _fades:
		if fade != null and fade.is_valid():
			fade.kill()

	var previous: AudioStreamPlayer = null
	if _active_index >= 0:
		previous = _players[_active_index]
		var fade_out := create_tween()
		_fades[_active_index] = fade_out
		fade_out.tween_property(previous, "volume_db", SILENCE_DB, FADE_SECONDS)
		fade_out.tween_callback(previous.stop)

	next_player.stop()
	next_player.stream = stream
	next_player.volume_db = SILENCE_DB
	next_player.play()
	var fade_in := create_tween()
	_fades[next_index] = fade_in
	fade_in.tween_property(next_player, "volume_db", CUE_VOLUME_DB[cue], FADE_SECONDS)
	_active_index = next_index
	current_cue = cue


func _load_stream(cue: String) -> AudioStream:
	if _streams.has(cue):
		return _streams[cue]
	var source := load(TRACKS[cue]) as AudioStream
	if source == null:
		return null
	var stream := source.duplicate() as AudioStream
	if stream is AudioStreamOggVorbis:
		stream.loop = true
		stream.loop_offset = 0.0
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	_streams[cue] = stream
	return stream


func is_playing() -> bool:
	return _active_index >= 0 and _players[_active_index].playing
