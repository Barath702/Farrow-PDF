package com.example.pdfviewer

import android.database.Cursor
import android.os.Bundle
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "pdf_query_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAllPdfs" -> {
                    val pdfFiles = queryPdfs()
                    result.success(pdfFiles)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun queryPdfs(): List<Map<String, Any?>> {
        val pdfList = mutableListOf<Map<String, Any?>>()

        val uri = MediaStore.Files.getContentUri("external")

        // Use DATA column to get actual file paths (works with MANAGE_EXTERNAL_STORAGE)
        val projection = arrayOf(
            MediaStore.Files.FileColumns._ID,
            MediaStore.Files.FileColumns.DATA,
            MediaStore.Files.FileColumns.DISPLAY_NAME,
            MediaStore.Files.FileColumns.SIZE,
            MediaStore.Files.FileColumns.DATE_MODIFIED,
            MediaStore.Files.FileColumns.MIME_TYPE
        )

        val selection = "${MediaStore.Files.FileColumns.MIME_TYPE}=?"
        val selectionArgs = arrayOf("application/pdf")

        val sortOrder = "${MediaStore.Files.FileColumns.DATE_MODIFIED} DESC"

        val cursor = contentResolver.query(uri, projection, selection, selectionArgs, sortOrder)

        cursor?.use {
            val dataColumn = it.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATA)
            val nameColumn = it.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DISPLAY_NAME)
            val sizeColumn = it.getColumnIndexOrThrow(MediaStore.Files.FileColumns.SIZE)
            val dateColumn = it.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATE_MODIFIED)

            while (it.moveToNext()) {
                val filePath = it.getString(dataColumn)
                val name = it.getString(nameColumn)
                val size = it.getLong(sizeColumn)
                val date = it.getLong(dateColumn) // seconds since epoch

                // Skip if file doesn't exist or path is null
                if (filePath == null || !File(filePath).exists()) continue

                pdfList.add(
                    mapOf(
                        "filePath" to filePath,
                        "fileName" to name,
                        "fileSize" to size,
                        "dateModified" to date
                    )
                )
            }
        }

        return pdfList
    }
}
