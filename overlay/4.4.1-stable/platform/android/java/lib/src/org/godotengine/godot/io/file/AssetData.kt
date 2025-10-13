/**************************************************************************/
/*  AssetData.kt                                                          */
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

package org.godotengine.godot.io.file

import android.content.Context
import android.util.Log
import org.godotengine.godot.error.Error
import org.godotengine.godot.io.directory.AssetsDirectoryAccess
import java.io.File
import java.io.IOException
import java.io.RandomAccessFile
import java.lang.UnsupportedOperationException
import java.nio.ByteBuffer
import java.nio.channels.FileChannel

internal class AssetData(
    context: Context,
    private val filePath: String,
    accessFlag: FileAccessFlags
) : DataAccess() {

    companion object {
        private val TAG = AssetData::class.java.simpleName

        private fun v(msg: String) {
            Log.v(TAG, msg)
        }

        fun fileExists(context: Context, path: String): Boolean {
            val assetsPath = AssetsDirectoryAccess.getAssetsPath(path)
            val file = File(File(context.filesDir, "assets"), assetsPath)
            val exists = file.exists() && file.isFile
            v("fileExists('$path') -> $exists")
            return exists
        }

        fun fileLastModified(path: String): Long {
            v("fileLastModified('$path') -> 0")
            return 0L
        }

        fun delete(path: String): Boolean {
            v("delete('$path') not supported -> false")
            return false
        }

        fun rename(from: String, to: String): Boolean {
            v("rename('$from' -> '$to') not supported -> false")
            return false
        }
    }

    private val file: File
    private val randomAccessFile: RandomAccessFile
    internal val readChannel: FileChannel

    private var position = 0L
    private val length: Long

    init {
        v("init(filePath='$filePath', accessFlag=$accessFlag)")
        if (accessFlag == FileAccessFlags.WRITE) {
            throw UnsupportedOperationException("Writing to the 'assets' directory is not supported")
        }

        val assetsPath = AssetsDirectoryAccess.getAssetsPath(filePath)
        file = File(File(context.filesDir, "assets"), assetsPath)
        v("Resolved assets path: ${file.absolutePath}")

        if (!file.exists()) {
            throw IOException("File does not exist: ${file.absolutePath}")
        }

        randomAccessFile = RandomAccessFile(file, "r")
        readChannel = randomAccessFile.channel
        length = file.length()

        v("File opened, length=$length")
    }

    override fun close() {
        v("close() called at pos=$position / size=$length")
        try {
            randomAccessFile.close()
            v("close() successful")
        } catch (e: IOException) {
            Log.w(TAG, "Exception when closing file $filePath.", e)
        }
    }

    override fun flush() {
        Log.w(TAG, "flush() is not supported.")
        v("flush() called but not supported")
    }

    override fun seek(position: Long) {
        v("seek($position) from current=$this.position")
        try {
            readChannel.position(position)
            this.position = position
            endOfFile = this.position >= length
            v("seek() complete, newPos=$this.position, eof=$endOfFile")
        } catch (e: IOException) {
            Log.w(TAG, "Exception when seeking file $filePath.", e)
        }
    }

    override fun resize(length: Long): Error {
        Log.w(TAG, "resize() is not supported.")
        v("resize($length) not supported")
        return Error.ERR_UNAVAILABLE
    }

    override fun position(): Long {
        v("position() -> $position")
        return position
    }

    override fun size(): Long {
        v("size() -> $length")
        return length
    }

    override fun read(buffer: ByteBuffer): Int {
        val requested = buffer.remaining()
        v("read(requested=$requested) at filePos=$position")
        return try {
            val readBytes = readChannel.read(buffer)
            if (readBytes == -1) {
                endOfFile = true
                v("read() -> EOF")
                0
            } else {
                position += readBytes
                endOfFile = position >= length
                v("read() -> $readBytes bytes, newPos=$position, eof=$endOfFile")
                readBytes
            }
        } catch (e: IOException) {
            Log.w(TAG, "Exception while reading from $filePath.", e)
            0
        }
    }

    override fun write(buffer: ByteBuffer): Boolean {
        Log.w(TAG, "write() is not supported.")
        v("write(${buffer.remaining()} bytes) not supported")
        return false
    }
}
