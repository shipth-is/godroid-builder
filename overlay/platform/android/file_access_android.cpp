/**************************************************************************/
/*  file_access_android.cpp                                               */
/**************************************************************************/
/*                         This file is part of:                          */
/*                             GODOT ENGINE                               */
/*                        https://godotengine.org                         */
/**************************************************************************/
/* Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md). */
/* Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.                  */
/*                                                                        */
/* Permission is hereby granted, free of charge, to any person obtaining  */
/* a copy of this software and associated documentation files (the        */
/* "Software"), to deal in the Software without restriction, including    */
/* without limitation the rights to use, copy, modify, merge, publish,    */
/* distribute, sublicense, and/or sell copies of the Software, and to     */
/* permit persons to whom the Software is furnished to do so, subject to  */
/* the following conditions:                                              */
/*                                                                        */
/* The above copyright notice and this permission notice shall be         */
/* included in all copies or substantial portions of the Software.        */
/*                                                                        */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,        */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. */
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 */
/**************************************************************************/

#include "file_access_android.h"

#include "core/string/print_string.h"
#include "thread_jandroid.h"

#include <android/asset_manager_jni.h>
#include <android/log.h>
#include <cstdio>
#include <inttypes.h> // for PRIu64 / PRId64

#define FAA_TAG "FileAccessAndroid"
#define VLOG(fmt, ...) __android_log_print(ANDROID_LOG_VERBOSE, FAA_TAG, fmt, ##__VA_ARGS__)
#define WLOG(fmt, ...) __android_log_print(ANDROID_LOG_WARN,    FAA_TAG, fmt, ##__VA_ARGS__)
#define ELOG(fmt, ...) __android_log_print(ANDROID_LOG_ERROR,   FAA_TAG, fmt, ##__VA_ARGS__)

// Keep this static: it's a shared configuration value, not a handle.
String FileAccessAndroid::extracted_assets_path = "/data/user/0/com.shipthis.godotdemo/files/assets";

String FileAccessAndroid::get_path() const {
	VLOG("[%p] get_path() -> %s", this, path_src.utf8().get_data());
	return path_src;
}

String FileAccessAndroid::get_path_absolute() const {
	VLOG("[%p] get_path_absolute() -> %s", this, absolute_path.utf8().get_data());
	return absolute_path;
}

Error FileAccessAndroid::open_internal(const String &p_path, int p_mode_flags) {
	VLOG("[%p] open_internal(path='%s', flags=%d) BEGIN", this, p_path.utf8().get_data(), p_mode_flags);

	_close(); // close any previously open file for THIS instance

	path_src = p_path;
	String path = fix_path(p_path).simplify_path();
	absolute_path = path;

	if (path.begins_with("/")) {
		path = path.substr(1, path.length());
	} else if (path.begins_with("res://")) {
		path = path.substr(6, path.length());
	}

	// Read-only on Android here.
	ERR_FAIL_COND_V(p_mode_flags & FileAccess::WRITE, ERR_UNAVAILABLE);

	// Use extracted assets path under internal storage.
	String full_path = extracted_assets_path + "/" + path;
	VLOG("[%p] Resolved full_path='%s'", this, full_path.utf8().get_data());

	file_handle = fopen(full_path.utf8().get_data(), "rb");
	if (!file_handle) {
		ELOG("[%p] fopen failed for '%s'", this, full_path.utf8().get_data());
		return ERR_CANT_OPEN;
	}

	// Determine file size.
	fseek(file_handle, 0, SEEK_END);
	len = (uint64_t)ftell(file_handle);
	fseek(file_handle, 0, SEEK_SET);

	pos = 0;
	eof = false;

	VLOG("[%p] open_internal(): OK (len=%" PRIu64 ")", this, (uint64_t)len);
	return OK;
}

void FileAccessAndroid::_close() {
	if (!file_handle) {
		VLOG("[%p] _close(): no file open", this);
		return;
	}
	VLOG("[%p] _close(): closing file (pos=%" PRIu64 "/len=%" PRIu64 ")", this, (uint64_t)pos, (uint64_t)len);
	fclose(file_handle);
	file_handle = nullptr;
}

bool FileAccessAndroid::is_open() const {
	const bool open = (file_handle != nullptr);
	VLOG("[%p] is_open() -> %s", this, open ? "true" : "false");
	return open;
}

void FileAccessAndroid::seek(uint64_t p_position) {
	ERR_FAIL_NULL(file_handle);
	VLOG("[%p] seek(%" PRIu64 ") from %" PRIu64, this, (uint64_t)p_position, (uint64_t)pos);

	fseek(file_handle, (long)p_position, SEEK_SET);
	pos = p_position;
	if (pos > len) {
		pos = len;
		eof = true;
	} else {
		eof = false;
	}

	VLOG("[%p] seek(): new pos=%" PRIu64 ", eof=%s", this, (uint64_t)pos, eof ? "true" : "false");
}

void FileAccessAndroid::seek_end(int64_t p_position) {
	ERR_FAIL_NULL(file_handle);
	VLOG("[%p] seek_end(%" PRId64 ")", this, (int64_t)p_position);

	fseek(file_handle, (long)p_position, SEEK_END);
	pos = len + p_position;
	if (pos > len) {
		pos = len;
	}
	eof = (pos >= len);

	VLOG("[%p] seek_end(): pos=%" PRIu64 ", len=%" PRIu64 ", eof=%s", this, (uint64_t)pos, (uint64_t)len, eof ? "true" : "false");
}

uint64_t FileAccessAndroid::get_position() const {
	VLOG("[%p] get_position() -> %" PRIu64, this, (uint64_t)pos);
	return pos;
}

uint64_t FileAccessAndroid::get_length() const {
	VLOG("[%p] get_length() -> %" PRIu64, this, (uint64_t)len);
	return len;
}

bool FileAccessAndroid::eof_reached() const {
	VLOG("[%p] eof_reached() -> %s", this, eof ? "true" : "false");
	return eof;
}

uint64_t FileAccessAndroid::get_buffer(uint8_t *p_dst, uint64_t p_length) const {
	ERR_FAIL_COND_V(!p_dst && p_length > 0, (uint64_t)-1);
	ERR_FAIL_NULL_V(file_handle, (uint64_t)0);

	VLOG("[%p] get_buffer(len=%" PRIu64 ") at pos=%" PRIu64, this, (uint64_t)p_length, (uint64_t)pos);

	size_t r = fread(p_dst, 1, (size_t)p_length, file_handle);

	// update EOF/pos (members may be declared 'mutable' in the header to allow this in a const method)
	if (pos + p_length > len) {
		eof = true;
	}
	if (r > 0) {
		pos += r;
		if (pos > len) {
			pos = len;
		}
	}

	VLOG("[%p] get_buffer() -> read=%zu, new pos=%" PRIu64 ", eof=%s", this, r, (uint64_t)pos, eof ? "true" : "false");
	return (uint64_t)r;
}

Error FileAccessAndroid::get_error() const {
	const Error e = eof ? ERR_FILE_EOF : OK;
	VLOG("[%p] get_error() -> %d", this, (int)e);
	return e;
}

void FileAccessAndroid::flush() {
	WLOG("[%p] flush() not supported", this);
	ERR_FAIL();
}

bool FileAccessAndroid::store_buffer(const uint8_t *p_src, uint64_t p_length) {
	WLOG("[%p] store_buffer(%p, %" PRIu64 ") not supported", this, p_src, (uint64_t)p_length);
	ERR_FAIL_V(false);
}

bool FileAccessAndroid::file_exists(const String &p_path) {
	String path = fix_path(p_path).simplify_path();

	if (path.begins_with("/")) {
		path = path.substr(1, path.length());
	} else if (path.begins_with("res://")) {
		path = path.substr(6, path.length());
	}

	String full_path = extracted_assets_path + "/" + path;

	VLOG("[static] file_exists('%s') -> checking '%s'", p_path.utf8().get_data(), full_path.utf8().get_data());

	FILE *test_file = fopen(full_path.utf8().get_data(), "rb");
	if (!test_file) {
		VLOG("[static] file_exists() -> false");
		return false;
	}
	fclose(test_file);
	VLOG("[static] file_exists() -> true");
	return true;
}

void FileAccessAndroid::close() {
	VLOG("[%p] close() called", this);
	_close();
}

FileAccessAndroid::~FileAccessAndroid() {
	VLOG("[%p] ~FileAccessAndroid()", this);
	_close();
}

void FileAccessAndroid::setup(jobject p_asset_manager) {
	// Initialize/confirm the extracted assets path if needed.
	// (If you make it configurable, change this value before opening files.)
	VLOG("[static] setup(): extracted_assets_path='%s'", extracted_assets_path.utf8().get_data());
}

void FileAccessAndroid::terminate() {
	VLOG("[static] terminate()");
	// No explicit cleanup needed here.
}
