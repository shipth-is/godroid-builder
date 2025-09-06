/**************************************************************************/
/*  AssetsDirectoryAccess.kt                                              */
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
package org.godotengine.godot.io.directory

import android.content.Context
import android.util.Log
import android.util.SparseArray
import org.godotengine.godot.io.StorageScope
import org.godotengine.godot.io.directory.DirectoryAccessHandler.Companion.INVALID_DIR_ID
import org.godotengine.godot.io.directory.DirectoryAccessHandler.Companion.STARTING_DIR_ID
import java.io.File

/**
 * Handles directories access within the Android assets directory.
 */
internal class AssetsDirectoryAccess(private val context: Context) : DirectoryAccessHandler.DirectoryAccess {

    companion object {
        private val TAG = AssetsDirectoryAccess::class.java.simpleName

        private fun v(msg: String) {
            Log.v(TAG, msg)
        }

        internal fun getAssetsRelativePath(originalPath: String): String {
            var path = originalPath
            if (path.startsWith(StorageScope.Identifier.ASSETS_PREFIX)) {
                path = path.substring(StorageScope.Identifier.ASSETS_PREFIX.length)
            }
            if (path.startsWith(File.separator)) {
                path = path.substring(File.separator.length)
            }
            v("getAssetsRelativePath('$originalPath') -> '$path'")
            return path
        }

        internal fun getAssetsPath(originalPath: String): String {
            val path = when {
                originalPath.startsWith(File.separator) ->
                    originalPath.substring(File.separator.length)
                originalPath.startsWith(StorageScope.Identifier.ASSETS_PREFIX) ->
                    originalPath.substring(StorageScope.Identifier.ASSETS_PREFIX.length)
                else -> originalPath
            }
            v("getAssetsPath('$originalPath') -> '$path'")
            return path
        }
    }

    private data class DirData(val dirFile: File, val files: Array<File>, var current: Int = 0)

    private val baseAssetsDir = File(context.filesDir, "assets")

    private var lastDirId = STARTING_DIR_ID
    private val dirs = SparseArray<DirData>()

    private fun mapToLocalFile(originalPath: String): File {
        val relative = getAssetsRelativePath(originalPath)
        val f = File(baseAssetsDir, relative)
        v("mapToLocalFile('$originalPath') -> '${f.absolutePath}'")
        return f
    }

    override fun hasDirId(dirId: Int): Boolean {
        val exists = dirs.indexOfKey(dirId) >= 0
        v("hasDirId($dirId) -> $exists")
        return exists
    }

    override fun dirOpen(path: String): Int {
        v("dirOpen('$path')")
        val dirFile = mapToLocalFile(path)
        if (!dirFile.isDirectory) {
            v("dirOpen('$path') -> INVALID_DIR_ID (not a directory)")
            return INVALID_DIR_ID
        }

        val files = dirFile.listFiles()
        if (files == null) {
            v("dirOpen('$path') -> INVALID_DIR_ID (listFiles returned null)")
            return INVALID_DIR_ID
        }

        val dirData = DirData(dirFile, files)
        val id = ++lastDirId
        dirs.put(id, dirData)
        v("dirOpen('$path') -> id=$id (files=${files.size})")
        return id
    }

    override fun dirExists(path: String): Boolean {
        val exists = try {
            mapToLocalFile(path).isDirectory
        } catch (e: SecurityException) {
            false
        }
        v("dirExists('$path') -> $exists")
        return exists
    }

    override fun fileExists(path: String): Boolean {
        val exists = try {
            val f = mapToLocalFile(path)
            f.exists() && f.isFile
        } catch (e: SecurityException) {
            false
        }
        v("fileExists('$path') -> $exists")
        return exists
    }

    override fun dirIsDir(dirId: Int): Boolean {
        val dd: DirData = dirs[dirId]
        var idx = dd.current
        if (idx > 0) idx--
        val result = idx < dd.files.size && dd.files[idx].isDirectory
        v("dirIsDir(id=$dirId) idx=$idx -> $result")
        return result
    }

    override fun isCurrentHidden(dirId: Int): Boolean {
        val dd = dirs[dirId]
        var idx = dd.current
        if (idx > 0) idx--
        val result = idx < dd.files.size && dd.files[idx].isHidden
        v("isCurrentHidden(id=$dirId) idx=$idx -> $result")
        return result
    }

    override fun dirNext(dirId: Int): String {
        val dd: DirData = dirs[dirId]
        return if (dd.current >= dd.files.size) {
            dd.current++
            v("dirNext(id=$dirId) -> end reached")
            ""
        } else {
            val name = dd.files[dd.current++].name
            v("dirNext(id=$dirId) -> '$name'")
            name
        }
    }

    override fun dirClose(dirId: Int) {
        dirs.remove(dirId)
        v("dirClose(id=$dirId)")
    }

    override fun getDriveCount(): Int {
        v("getDriveCount() -> 0")
        return 0
    }

    override fun getDrive(drive: Int): String {
        v("getDrive($drive) -> ''")
        return ""
    }

    override fun makeDir(dir: String): Boolean {
        v("makeDir('$dir') not supported -> false")
        return false
    }

    override fun getSpaceLeft(): Long {
        v("getSpaceLeft() -> 0")
        return 0L
    }

    override fun rename(from: String, to: String): Boolean {
        v("rename('$from' -> '$to') not supported -> false")
        return false
    }

    override fun remove(filename: String): Boolean {
        v("remove('$filename') not supported -> false")
        return false
    }
}
