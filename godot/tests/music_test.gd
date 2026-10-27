extends SceneTree
## Exercise the real imported music, including rapid transitions and EOF loops.
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var director := MusicDirector.new()
	root.add_child(director)
	director.play_cue("library")
	check(director.is_playing(), "Menu score starts")
	var player: AudioStreamPlayer = director._players[director._active_index]
	check(player.stream is AudioStreamOggVorbis, "Menu uses compressed Vorbis")
	check(player.stream.get_length() > 150 and player.stream.get_length() < 190, "Entire composition is present")
	check(player.stream.loop, "Menu composition repeats")
	await create_timer(.25).timeout
	check(absf(player.volume_db - director.CUE_VOLUME_DB.library) < .05, "Initial fade preserves the opening drum attack")
	var position := player.get_playback_position()
	director.play_cue("library")
	check(player.get_playback_position() >= position - .05, "Opening another menu does not restart the melody")
	# Reuse both players while their previous stop callbacks would still be pending.
	for cue in ["battle", "library", "battle", "library"]:
		director.play_cue(cue)
		await create_timer(.08).timeout
	await create_timer(1.05).timeout
	player = director._players[director._active_index]
	check(director.current_cue == "library" and director.is_playing(), "Rapid transitions cannot silence the active cue")
	check(not director._players[1 - director._active_index].playing, "Old cue stops after the crossfade")
	check(director.get_child_count() == 2, "Switching does not accumulate audio players")
	player.seek(player.stream.get_length() - .15)
	await create_timer(.45).timeout
	check(player.playing and player.get_playback_position() < 1.0, "Vorbis loops at its actual end")
	director.play_cue("battle")
	await create_timer(1.05).timeout
	player = director._players[director._active_index]
	check(player.stream is AudioStreamOggVorbis and player.playing, "Battle drum loop plays as compressed Vorbis")
	check(player.stream.get_length() > 59.0 and player.stream.get_length() < 61.0, "Battle drums use a slower 64 BPM march")
	check(director.CUE_VOLUME_DB.battle > director.CUE_VOLUME_DB.library, "Battle drums are mixed more powerfully than the menu score")
	check(absf(player.volume_db - director.CUE_VOLUME_DB.battle) < .05, "Battle drums finish fading in at their stronger level")
	player.seek(player.stream.get_length() - .15)
	await create_timer(.45).timeout
	check(player.playing and player.get_playback_position() < 1.0, "Battle drums loop at their actual end")
	director.queue_free()
	await process_frame
	# Let the audio mixer retire the stopped playback before engine shutdown.
	await create_timer(.12).timeout
	print("MUSIC: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
