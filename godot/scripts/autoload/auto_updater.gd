extends Node
## Auto-updater: checks for new game version on startup and downloads updated .pck.
## Compares local GAME_VERSION with server's version.txt.
## If newer version found, downloads .pck and restarts the game.

const UPDATE_URL := "https://chibiroyale.xyz/version.txt"
const PCK_URL := "https://chibiroyale.xyz/updates/ChibiRoyale.pck"
const CHECK_TIMEOUT := 5.0

signal update_available(remote_version: String)
signal update_progress(percent: float)
signal update_completed()
signal update_failed(reason: String)
signal check_completed(has_update: bool)

var _http_check: HTTPRequest = null
var _http_download: HTTPRequest = null
var _remote_version: String = ""
var is_updating: bool = false


func _ready() -> void:
	# Don't check for updates on headless server
	if DisplayServer.get_name() == "headless":
		return
	check_for_update()


func check_for_update() -> void:
	_http_check = HTTPRequest.new()
	_http_check.timeout = CHECK_TIMEOUT
	add_child(_http_check)
	_http_check.request_completed.connect(_on_check_completed)
	var err := _http_check.request(UPDATE_URL)
	if err != OK:
		print("[AutoUpdater] Failed to send version check: %s" % error_string(err))
		check_completed.emit(false)


func _on_check_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_http_check.queue_free()
	_http_check = null

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("[AutoUpdater] Version check failed (result=%d, code=%d)" % [result, response_code])
		check_completed.emit(false)
		return

	_remote_version = body.get_string_from_utf8().strip_edges()
	var local := GameSettings.GAME_VERSION
	if _remote_version != local and _remote_version != "":
		print("[AutoUpdater] Update available: %s -> %s" % [local, _remote_version])
		update_available.emit(_remote_version)
		check_completed.emit(true)
	else:
		print("[AutoUpdater] Up to date (v%s)" % local)
		check_completed.emit(false)


func start_download() -> void:
	if is_updating:
		return
	is_updating = true

	# Get the path where the .pck lives (next to the executable)
	var exe_path := OS.get_executable_path()
	var exe_dir := exe_path.get_base_dir()
	var pck_path := exe_dir.path_join("ChibiRoyale.pck")

	# If running from editor, save to a temp location
	if OS.has_feature("editor"):
		pck_path = "user://ChibiRoyale_update.pck"
		print("[AutoUpdater] Editor mode - saving to %s" % pck_path)

	_http_download = HTTPRequest.new()
	_http_download.download_file = pck_path
	_http_download.timeout = 120.0
	add_child(_http_download)
	_http_download.request_completed.connect(_on_download_completed.bind(pck_path))

	var err := _http_download.request(PCK_URL)
	if err != OK:
		print("[AutoUpdater] Failed to start download: %s" % error_string(err))
		is_updating = false
		update_failed.emit("Download request failed")
		return

	print("[AutoUpdater] Downloading update from %s" % PCK_URL)
	# Start progress polling
	set_process(true)


func _process(_delta: float) -> void:
	if _http_download and is_updating:
		var body_size := _http_download.get_body_size()
		var downloaded := _http_download.get_downloaded_bytes()
		if body_size > 0:
			var percent := float(downloaded) / float(body_size) * 100.0
			update_progress.emit(percent)
	else:
		set_process(false)


func _on_download_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray, pck_path: String) -> void:
	_http_download.queue_free()
	_http_download = null
	is_updating = false
	set_process(false)

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("[AutoUpdater] Download failed (result=%d, code=%d)" % [result, response_code])
		# Clean up partial download
		if FileAccess.file_exists(pck_path):
			DirAccess.remove_absolute(pck_path)
		update_failed.emit("Download failed")
		return

	print("[AutoUpdater] Update downloaded to %s" % pck_path)
	update_completed.emit()

	# Restart the game to use the new .pck
	_restart_game()


func _restart_game() -> void:
	print("[AutoUpdater] Restarting game...")
	var exe := OS.get_executable_path()
	var args := OS.get_cmdline_args()
	OS.create_process(exe, args)
	get_tree().quit()
