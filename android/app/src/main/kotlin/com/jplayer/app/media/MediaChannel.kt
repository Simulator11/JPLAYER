package com.jplayer.app.media

import android.app.Activity
import android.content.ContentUris
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

/**
 * Native MediaStore bridge.
 *
 * Android's scoped storage means the Flutter layer cannot reliably walk the
 * filesystem, so library discovery lives here. Queries use MediaStore, the
 * supported way to read a user's media on modern Android without requesting
 * unrestricted storage access.
 */
class MediaChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.jplayer/media"
        private const val ARTWORK_DIR = "jplayer_artwork"
        private const val MAX_ARTWORK_SIZE = 720
        private const val MAX_THUMBNAIL_SIZE = 480
    }

    private val context: Context = activity.applicationContext
    private val executor = Executors.newFixedThreadPool(3)
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "querySongs" -> runAsync(result) { querySongs() }
            "queryVideos" -> runAsync(result) { queryVideos() }
            "getArtwork" -> {
                val albumId = call.argument<Number>("albumId")?.toLong()
                val songId = call.argument<Number>("songId")?.toLong()
                val path = call.argument<String>("path")
                runAsync(result) { getArtwork(albumId, songId, path) }
            }
            "getVideoThumbnail" -> {
                val videoId = call.argument<Number>("videoId")?.toLong()
                val path = call.argument<String>("path")
                runAsync(result) { getVideoThumbnail(videoId, path) }
            }
            "refreshMediaStore" -> {
                val paths = call.argument<List<String>>("paths") ?: emptyList()
                runAsync(result) { refreshMediaStore(paths) }
            }
            "getPlatformInfo" -> result.success(
                mapOf(
                    "sdkInt" to Build.VERSION.SDK_INT,
                    "release" to Build.VERSION.RELEASE,
                    "manufacturer" to Build.MANUFACTURER,
                    "model" to Build.MODEL,
                ),
            )
            "setScreenBrightness" -> {
                val value = call.argument<Number>("value")?.toFloat()
                applyScreenBrightness(value)
                result.success(true)
            }
            "clearArtworkCache" -> runAsync(result) { clearArtworkCache() }
            else -> result.notImplemented()
        }
    }

    private fun runAsync(result: MethodChannel.Result, block: () -> Any?) {
        executor.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (e: SecurityException) {
                mainHandler.post {
                    result.error("permission_denied", e.message ?: "Media permission denied", null)
                }
            } catch (e: Throwable) {
                mainHandler.post {
                    result.error("media_error", e.message ?: e.javaClass.simpleName, null)
                }
            }
        }
    }

    // ---------------------------------------------------------------------
    // Audio library
    // ---------------------------------------------------------------------

    private fun audioCollection(): Uri =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }

    private fun querySongs(): List<Map<String, Any?>> {
        val songs = ArrayList<Map<String, Any?>>()
        val genreBySong = queryGenreMap()
        val projection = mutableListOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ARTIST_ID,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.ALBUM_ID,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.DATE_ADDED,
            MediaStore.Audio.Media.DATE_MODIFIED,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.TRACK,
            MediaStore.Audio.Media.YEAR,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            projection.add(MediaStore.Audio.Media.RELATIVE_PATH)
        }

        val selection = "(${MediaStore.Audio.Media.IS_MUSIC} != 0 " +
            "OR ${MediaStore.Audio.Media.MIME_TYPE} LIKE 'audio/%') " +
            "AND ${MediaStore.Audio.Media.DURATION} > 1000"
        val sortOrder = "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC"

        val audioCursor = context.contentResolver.query(
            audioCollection(),
            projection.toTypedArray(),
            selection,
            null,
            sortOrder,
        ) ?: throw IllegalStateException("MediaStore audio query returned no cursor")
        audioCursor.use { cursor ->
            val idIdx = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val titleIdx = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artistIdx = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val artistIdIdx = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST_ID)
            val albumIdx = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
            val albumIdIdx = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)
            val durationIdx = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            val sizeIdx = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
            val dateAddedIdx = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)
            val dateModifiedIdx = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_MODIFIED)
            val dataIdx = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
            val displayNameIdx = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME)
            val trackIdx = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TRACK)
            val yearIdx = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.YEAR)
            val relativeIdx = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                cursor.getColumnIndex(MediaStore.Audio.Media.RELATIVE_PATH)
            } else {
                -1
            }

            while (cursor.moveToNext()) {
                val id = cursor.getLong(idIdx)
                val fileName = cursor.getString(displayNameIdx) ?: ""
                var path = cursor.getString(dataIdx) ?: ""
                if (path.isEmpty()) {
                    path = ContentUris.withAppendedId(audioCollection(), id).toString()
                }
                val relativePath = if (relativeIdx >= 0) {
                    (cursor.getString(relativeIdx) ?: "").trim('/')
                } else {
                    deriveRelativePath(path)
                }
                val artist = cursor.getString(artistIdx)
                val album = cursor.getString(albumIdx)
                songs.add(
                    mapOf(
                        "id" to id,
                        "title" to cleanTitle(cursor.getString(titleIdx), fileName),
                        "artist" to (artist ?: ""),
                        "artistId" to if (cursor.isNull(artistIdIdx)) null else cursor.getLong(artistIdIdx),
                        "album" to (album ?: ""),
                        "albumId" to if (cursor.isNull(albumIdIdx)) null else cursor.getLong(albumIdIdx),
                        "genre" to genreBySong[id],
                        "duration" to cursor.getLong(durationIdx),
                        "size" to cursor.getLong(sizeIdx),
                        "dateAdded" to cursor.getLong(dateAddedIdx),
                        "dateModified" to cursor.getLong(dateModifiedIdx),
                        "path" to if (path.startsWith("/")) path else "",
                        "uri" to if (path.startsWith("/")) {
                            ContentUris.withAppendedId(audioCollection(), id).toString()
                        } else {
                            path
                        },
                        "relativePath" to relativePath,
                        "fileName" to fileName,
                        "track" to cursor.getInt(trackIdx),
                        "year" to cursor.getInt(yearIdx),
                    ),
                )

            }
        }
        return songs
    }

    /**
     * Builds a songId -> genre name map. MediaStore has no genre column on
     * audio rows, so genre membership is resolved once per scan.
     */
    private fun queryGenreMap(): Map<Long, String> {
        val result = HashMap<Long, String>()
        try {
            val genresUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Audio.Genres.getContentUri(MediaStore.VOLUME_EXTERNAL)
            } else {
                MediaStore.Audio.Genres.EXTERNAL_CONTENT_URI
            }
            context.contentResolver.query(
                genresUri,
                arrayOf(MediaStore.Audio.Genres._ID, MediaStore.Audio.Genres.NAME),
                null,
                null,
                null,
            )?.use { genres ->
                val idIdx = genres.getColumnIndexOrThrow(MediaStore.Audio.Genres._ID)
                val nameIdx = genres.getColumnIndexOrThrow(MediaStore.Audio.Genres.NAME)
                while (genres.moveToNext()) {
                    val genreId = genres.getLong(idIdx)
                    val genreName = genres.getString(nameIdx) ?: continue
                    if (genreName.isBlank()) continue
                    try {
                        val membersUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            MediaStore.Audio.Genres.Members.getContentUri(
                                MediaStore.VOLUME_EXTERNAL,
                                genreId,
                            )
                        } else {
                            MediaStore.Audio.Genres.Members.getContentUri("external", genreId)
                        }
                        context.contentResolver.query(
                            membersUri,
                            arrayOf(MediaStore.Audio.Media._ID),
                            null,
                            null,
                            null,
                        )?.use { members ->
                            while (members.moveToNext()) {
                                result[members.getLong(0)] = genreName
                            }
                        }
                    } catch (_: Exception) {
                        // Some vendor MediaStores do not expose genre membership.
                    }
                }
            }
        } catch (_: Exception) {
            // Genres are optional; the rest of the library still works.
        }
        return result
    }

    // ---------------------------------------------------------------------
    // Video library (secondary feature)
    // ---------------------------------------------------------------------

    private fun videoCollection(): Uri =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        }

    private fun queryVideos(): List<Map<String, Any?>> {
        val videos = ArrayList<Map<String, Any?>>()
        val projection = arrayOf(
            MediaStore.Video.Media._ID,
            MediaStore.Video.Media.TITLE,
            MediaStore.Video.Media.DURATION,
            MediaStore.Video.Media.SIZE,
            MediaStore.Video.Media.DATE_ADDED,
            MediaStore.Video.Media.DATA,
            MediaStore.Video.Media.BUCKET_DISPLAY_NAME,
            MediaStore.Video.Media.WIDTH,
            MediaStore.Video.Media.HEIGHT,
            MediaStore.Video.Media.DISPLAY_NAME,
        )
        val videoCursor = context.contentResolver.query(
            videoCollection(),
            projection,
            "${MediaStore.Video.Media.DURATION} > 0",
            null,
            "${MediaStore.Video.Media.DATE_ADDED} DESC",
        ) ?: throw IllegalStateException("MediaStore video query returned no cursor")
        videoCursor.use { cursor ->
            val idIdx = cursor.getColumnIndexOrThrow(MediaStore.Video.Media._ID)
            val titleIdx = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.TITLE)
            val durationIdx = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION)
            val sizeIdx = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.SIZE)
            val dateIdx = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DATE_ADDED)
            val dataIdx = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DATA)
            val bucketIdx = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.BUCKET_DISPLAY_NAME)
            val widthIdx = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.WIDTH)
            val heightIdx = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.HEIGHT)
            val displayNameIdx = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DISPLAY_NAME)

            while (cursor.moveToNext()) {
                val id = cursor.getLong(idIdx)
                val fileName = cursor.getString(displayNameIdx) ?: ""
                var path = cursor.getString(dataIdx) ?: ""
                if (path.isEmpty()) {
                    path = ContentUris.withAppendedId(videoCollection(), id).toString()
                }
                videos.add(
                    mapOf(
                        "id" to id,
                        "title" to cleanTitle(cursor.getString(titleIdx), fileName),
                        "duration" to cursor.getLong(durationIdx),
                        "size" to cursor.getLong(sizeIdx),
                        "dateAdded" to cursor.getLong(dateIdx),
                        "path" to if (path.startsWith("/")) path else "",
                        "uri" to if (path.startsWith("/")) {
                            ContentUris.withAppendedId(videoCollection(), id).toString()
                        } else {
                            path
                        },
                        "bucket" to (cursor.getString(bucketIdx) ?: ""),
                        "width" to cursor.getInt(widthIdx),
                        "height" to cursor.getInt(heightIdx),
                    ),
                )
            }
        }
        return videos
    }

    // ---------------------------------------------------------------------
    // Artwork
    // ---------------------------------------------------------------------

    private fun artworkDir(): File = File(context.cacheDir, ARTWORK_DIR).apply { mkdirs() }

    private fun getArtwork(albumId: Long?, songId: Long?, path: String?): String? {
        val key = when {
            albumId != null && albumId > 0 -> "album_$albumId"
            songId != null && songId > 0 -> "song_$songId"
            else -> return null
        }
        val outFile = File(artworkDir(), "$key.jpg")
        if (outFile.exists() && outFile.length() > 0) return outFile.absolutePath

        val retriever = MediaMetadataRetriever()
        try {
            when {
                !path.isNullOrBlank() && !path.startsWith("content://") && File(path).exists() ->
                    retriever.setDataSource(path)
                songId != null && songId > 0 ->
                    retriever.setDataSource(
                        context,
                        ContentUris.withAppendedId(audioCollection(), songId),
                    )
                albumId != null && albumId > 0 -> {
                    val albumSong = firstSongOfAlbum(albumId) ?: return null
                    retriever.setDataSource(albumSong)
                }
                else -> return null
            }
            val bytes = retriever.embeddedPicture
            if (bytes != null && bytes.isNotEmpty()) {
                val bitmap = decodeSampled(bytes, MAX_ARTWORK_SIZE)
                if (bitmap != null) {
                    return saveBitmap(bitmap, outFile)?.absolutePath
                }
            }
        } catch (_: Exception) {
            // Fall through to the album-art content provider.
        } finally {
            try {
                retriever.release()
            } catch (_: Exception) {
            }
        }

        if (albumId != null && albumId > 0) {
            try {
                val albumArtUri = ContentUris.withAppendedId(
                    Uri.parse("content://media/external/audio/albumart"),
                    albumId,
                )
                context.contentResolver.openInputStream(albumArtUri)?.use { input ->
                    val bytes = input.readBytes()
                    val bitmap = decodeSampled(bytes, MAX_ARTWORK_SIZE) ?: return@use
                    return saveBitmap(bitmap, outFile)?.absolutePath
                }
            } catch (_: Exception) {
            }
        }
        return null
    }

    private fun firstSongOfAlbum(albumId: Long): String? {
        return try {
            context.contentResolver.query(
                audioCollection(),
                arrayOf(MediaStore.Audio.Media.DATA),
                "${MediaStore.Audio.Media.ALBUM_ID} = ?",
                arrayOf(albumId.toString()),
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else null
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun getVideoThumbnail(videoId: Long?, path: String?): String? {
        if (videoId == null && path.isNullOrBlank()) return null
        val key = if (videoId != null && videoId > 0) {
            "video_$videoId"
        } else {
            "video_${path.hashCode()}"
        }
        val outFile = File(artworkDir(), "$key.jpg")
        if (outFile.exists() && outFile.length() > 0) return outFile.absolutePath

        val retriever = MediaMetadataRetriever()
        try {
            if (!path.isNullOrBlank() && !path.startsWith("content://") && File(path).exists()) {
                retriever.setDataSource(path)
            } else if (videoId != null && videoId > 0) {
                retriever.setDataSource(
                    context,
                    ContentUris.withAppendedId(videoCollection(), videoId),
                )
            } else {
                return null
            }
            val frame = retriever.getFrameAtTime(
                1_000_000L,
                MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
            ) ?: retriever.frameAtTime ?: return null
            val scaled = scaleBitmap(frame, MAX_THUMBNAIL_SIZE)
            return saveBitmap(scaled, outFile)?.absolutePath
        } catch (_: Exception) {
            return null
        } finally {
            try {
                retriever.release()
            } catch (_: Exception) {
            }
        }
    }

    private fun decodeSampled(bytes: ByteArray, maxSize: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var sampleSize = 1
        while (bounds.outWidth / (sampleSize * 2) >= maxSize &&
            bounds.outHeight / (sampleSize * 2) >= maxSize
        ) {
            sampleSize *= 2
        }
        val options = BitmapFactory.Options().apply { inSampleSize = sampleSize }
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options) ?: return null
        return scaleBitmap(bitmap, maxSize)
    }

    private fun scaleBitmap(bitmap: Bitmap, maxSize: Int): Bitmap {
        val largest = maxOf(bitmap.width, bitmap.height)
        if (largest <= maxSize) return bitmap
        val ratio = maxSize.toFloat() / largest.toFloat()
        val width = (bitmap.width * ratio).toInt().coerceAtLeast(1)
        val height = (bitmap.height * ratio).toInt().coerceAtLeast(1)
        return Bitmap.createScaledBitmap(bitmap, width, height, true)
    }

    private fun saveBitmap(bitmap: Bitmap, outFile: File): File? {
        return try {
            outFile.parentFile?.mkdirs()
            FileOutputStream(outFile).use { output ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 88, output)
            }
            outFile
        } catch (_: Exception) {
            null
        }
    }

    private fun clearArtworkCache(): Boolean {
        return try {
            artworkDir().listFiles()?.forEach { it.delete() }
            true
        } catch (_: Exception) {
            false
        }
    }

    // ---------------------------------------------------------------------
    // Utilities
    // ---------------------------------------------------------------------

    private fun refreshMediaStore(paths: List<String>): Int {
        val realPaths = paths.filter { it.startsWith("/") }
        if (realPaths.isEmpty()) return 0
        MediaScannerConnection.scanFile(context, realPaths.toTypedArray(), null, null)
        return realPaths.size
    }

    private fun applyScreenBrightness(value: Float?) {
        activity.runOnUiThread {
            try {
                val params = activity.window.attributes
                params.screenBrightness = (value ?: -1f).coerceIn(-1f, 1f)
                activity.window.attributes = params
            } catch (_: Exception) {
            }
        }
    }

    private fun deriveRelativePath(path: String): String {
        val parent = File(path).parent ?: return ""
        return parent
            .substringAfter("/storage/emulated/0/", parent)
            .substringAfter("/storage/emulated/", parent)
            .trim('/')
    }

    private fun cleanTitle(rawTitle: String?, fileName: String): String {
        if (!rawTitle.isNullOrBlank()) return rawTitle
        return fileName.substringBeforeLast('.').ifBlank { "Unknown track" }
    }
}

