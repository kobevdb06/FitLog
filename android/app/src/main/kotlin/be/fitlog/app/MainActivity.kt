package be.fitlog.app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Extends FlutterFragmentActivity (not FlutterActivity) because local_auth
 * requires a FragmentActivity host to show the biometric prompt.
 *
 * It also lends the app a folder you pick yourself, through the storage
 * access framework: the automatic backup goes there, outside the app, so it
 * is still there after an uninstall or a wiped phone - and no storage
 * permission is needed, only the one you give for that one folder.
 */
class MainActivity : FlutterFragmentActivity() {
    private var pendingPick: MethodChannel.Result? = null
    private lateinit var pickFolder: ActivityResultLauncher<Uri?>
    private val main = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pickFolder =
            registerForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri ->
                val result = pendingPick ?: return@registerForActivityResult
                pendingPick = null
                if (uri == null) {
                    result.success(null)
                    return@registerForActivityResult
                }
                try {
                    contentResolver.takePersistableUriPermission(
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
                    )
                    result.success(mapOf("uri" to uri.toString(), "name" to folderName(uri)))
                } catch (error: Exception) {
                    result.error("pick", error.message, null)
                }
            }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "be.fitlog.app/folders")
            .setMethodCallHandler(::onFolderCall)
    }

    private fun onFolderCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pick" -> {
                if (pendingPick != null) {
                    result.error("busy", "Er staat al een mapkiezer open.", null)
                    return
                }
                pendingPick = result
                pickFolder.launch(null)
            }
            // The rest touches files, and a backup with photos is large: off
            // the main thread, answering on it.
            else -> Thread {
                try {
                    val answer = folderWork(call)
                    main.post { result.success(answer) }
                } catch (error: Exception) {
                    main.post { result.error(call.method, error.message, null) }
                }
            }.start()
        }
    }

    private fun folderWork(call: MethodCall): Any? {
        val tree = Uri.parse(call.argument<String>("uri"))
        return when (call.method) {
            "name" -> if (stillOurs(tree)) folderName(tree) else null
            "write" -> {
                val name = call.argument<String>("name")!!
                val source = File(call.argument<String>("source")!!)
                // Today's backup replaces today's backup: a folder does not
                // overwrite, it adds " (1)", and that is not a new day.
                children(tree).filter { it.name == name }.forEach {
                    DocumentsContract.deleteDocument(
                        contentResolver,
                        DocumentsContract.buildDocumentUriUsingTree(tree, it.id),
                    )
                }
                val created = DocumentsContract.createDocument(
                    contentResolver,
                    folderDocument(tree),
                    "application/octet-stream",
                    name,
                ) ?: throw IllegalStateException("Kon $name niet aanmaken.")
                contentResolver.openOutputStream(created)!!.use { out ->
                    source.inputStream().use { it.copyTo(out) }
                }
                null
            }
            "list" -> children(tree).map { mapOf("name" to it.name, "modified" to it.modified) }
            "delete" -> {
                val name = call.argument<String>("name")!!
                children(tree).filter { it.name == name }.forEach {
                    DocumentsContract.deleteDocument(
                        contentResolver,
                        DocumentsContract.buildDocumentUriUsingTree(tree, it.id),
                    )
                }
                null
            }
            "release" -> {
                if (stillOurs(tree)) {
                    contentResolver.releasePersistableUriPermission(
                        tree,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
                    )
                }
                null
            }
            else -> throw IllegalArgumentException("Onbekend: ${call.method}")
        }
    }

    private class Child(val id: String, val name: String, val modified: Long)

    /** Whether the app still holds the permission for [tree]. */
    private fun stillOurs(tree: Uri): Boolean =
        contentResolver.persistedUriPermissions.any { it.uri == tree && it.isWritePermission }

    private fun folderDocument(tree: Uri): Uri =
        DocumentsContract.buildDocumentUriUsingTree(
            tree,
            DocumentsContract.getTreeDocumentId(tree),
        )

    private fun folderName(tree: Uri): String? =
        contentResolver.query(
            folderDocument(tree),
            arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { if (it.moveToFirst()) it.getString(0) else null }

    private fun children(tree: Uri): List<Child> {
        val uri = DocumentsContract.buildChildDocumentsUriUsingTree(
            tree,
            DocumentsContract.getTreeDocumentId(tree),
        )
        val found = mutableListOf<Child>()
        contentResolver.query(
            uri,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_LAST_MODIFIED,
            ),
            null,
            null,
            null,
        )?.use {
            while (it.moveToNext()) {
                found += Child(it.getString(0), it.getString(1), it.getLong(2))
            }
        }
        return found
    }
}
