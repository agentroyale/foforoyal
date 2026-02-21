extends Node
## Auto-updater: checks for new game version on startup and downloads updated .pck.
## Compares local GAME_VERSION with server's version.txt.
## If newer version found, downloads .pck to user:// then copies to exe dir.
## Saves a version marker in user:// to prevent update loops when exe dir is read-only.

const UPDATE_URL := "https://chibiroyale.xyz/version.txt"
const PCK_URL := "https://chibiroyale.xyz/updates/ChibiRoyale.pck"
const CHECK_TIMEOUT := 5.0
const DOWNLOAD_PATH := "user://ChibiRoyale_update.pck"
const VERSION_MARKER := "user://installed_version.txt"

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
	if _remote_version == "":
		check_completed.emit(false)
		return

	var local := GameSettings.GAME_VERSION
	var marker := _read_version_marker()

	# Skip if GAME_VERSION matches OR we already downloaded this version
	if _remote_version == local or _remote_version == marker:
		print("[AutoUpdater] Up to date (v%s, marker=%s)" % [local, marker])
		check_completed.emit(false)
		return

	print("[AutoUpdater] Update available: %s -> %s" % [local, _remote_version])
	update_available.emit(_remote_version)
	check_completed.emit(true)


func start_download() -> void:
	if is_updating:
		return
	is_updating = true

	# Always download to user:// first (guaranteed writable on all platforms)
	_http_download = HTTPRequest.new()
	_http_download.download_file = DOWNLOAD_PATH
	_http_download.timeout = 120.0
	add_child(_http_download)
	_http_download.request_completed.connect(_on_download_completed)

	var err := _http_download.request(PCK_URL)
	if err != OK:
		print("[AutoUpdater] Failed to start download: %s" % error_string(err))
		is_updating = false
		update_failed.emit("Download request failed")
		return

	print("[AutoUpdater] Downloading update to %s" % DOWNLOAD_PATH)
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


func _on_download_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_http_download.queue_free()
	_http_download = null
	is_updating = false
	set_process(false)

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("[AutoUpdater] Download failed (result=%d, code=%d)" % [result, response_code])
		if FileAccess.file_exists(DOWNLOAD_PATH):
			DirAccess.remove_absolute(DOWNLOAD_PATH)
		update_failed.emit("Download failed")
		return

	# Verify the downloaded file exists and has content
	if not FileAccess.file_exists(DOWNLOAD_PATH):
		print("[AutoUpdater] Download completed but file not found at %s" % DOWNLOAD_PATH)
		update_failed.emit("Downloaded file missing")
		return

	var file_size := FileAccess.open(DOWNLOAD_PATH, FileAccess.READ)
	if not file_size or file_size.get_length() < 1024:
		print("[AutoUpdater] Downloaded file too small or unreadable")
		if file_size:
			file_size.close()
		if FileAccess.file_exists(DOWNLOAD_PATH):
			DirAccess.remove_absolute(DOWNLOAD_PATH)
		update_failed.emit("Downloaded file corrupt")
		return
	var download_size := file_size.get_length()
	file_size.close()

	print("[AutoUpdater] Download complete (%d bytes)" % download_size)

	# Copy from user:// to exe directory
	var target_path := _get_target_pck_path()
	var copy_ok := false

	if not OS.has_feature("editor"):
		var global_download := ProjectSettings.globalize_path(DOWNLOAD_PATH)
		var err := DirAccess.copy_absolute(global_download, target_path)
		if err == OK:
			# Verify the copy
			if FileAccess.file_exists(target_path):
				var check := FileAccess.open(target_path, FileAccess.READ)
				if check and check.get_length() == download_size:
					copy_ok = true
					print("[AutoUpdater] .pck copied to %s" % target_path)
				if check:
					check.close()
			if not copy_ok:
				print("[AutoUpdater] Copy verification failed")
		else:
			print("[AutoUpdater] Cannot copy to exe dir (err=%s). Permissions issue?" % error_string(err))

	# Save version marker BEFORE restart — prevents update loop
	_save_version_marker(_remote_version)

	# Clean up temp download
	if FileAccess.file_exists(DOWNLOAD_PATH):
		DirAccess.remove_absolute(DOWNLOAD_PATH)

	if copy_ok:
		update_completed.emit()
		_restart_game()
	else:
		# .pck couldn't be placed next to exe — update downloaded but can't be applied
		print("[AutoUpdater] Update v%s downloaded but could not be installed." % _remote_version)
		print("[AutoUpdater] Try running the game as administrator or reinstalling.")
		update_failed.emit("Cannot write to game folder. Try running as admin.")


func _get_target_pck_path() -> String:
	var exe_path := OS.get_executable_path()
	return exe_path.get_base_dir().path_join("ChibiRoyale.pck")


func _restart_game() -> void:
	print("[AutoUpdater] Restarting game...")
	var exe := OS.get_executable_path()
	var args := OS.get_cmdline_args()
	OS.create_process(exe, args)
	get_tree().quit()


func _read_version_marker() -> String:
	if not FileAccess.file_exists(VERSION_MARKER):
		return ""
	var f := FileAccess.open(VERSION_MARKER, FileAccess.READ)
	if not f:
		return ""
	var ver := f.get_as_text().strip_edges()
	f.close()
	return ver


func _save_version_marker(version: String) -> void:
	var f := FileAccess.open(VERSION_MARKER, FileAccess.WRITE)
	if f:
		f.store_string(version)
		f.close()
		print("[AutoUpdater] Version marker saved: %s" % version)
