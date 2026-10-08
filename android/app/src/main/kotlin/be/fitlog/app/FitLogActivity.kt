package be.fitlog.app

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
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
 *
 * And it switches the icon on the home screen. The launcher entries are two
 * aliases of this activity, each with its own icon, and one of them is on.
 * The dark one is called `.MainActivity`, the name this activity had: a
 * home-screen icon points at that name, and it would have gone from every
 * home screen with the update that brought the choice.
 */
class FitLogActivity : FlutterFragmentActivity() {

    private var pendingPick: MethodChannel.Result? = null

    /** The icon being switched to and the one being switched off, while
     *  this window closes for it. */
    private var switching: Pair<ComponentName, ComponentName>? = null
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

    override fun onDestroy() {
        super.onDestroy()
        val (on, off) = switching ?: return
        switching = null
        applicationContext.startActivity(
            Intent(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_LAUNCHER)
                .setComponent(on)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        turn(off, on = false)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "be.fitlog.app/folders")
            .setMethodCallHandler(::onFolderCall)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "be.fitlog.app/icon")
            .setMethodCallHandler(::onIconCall)
    }

    private val darkIcon get() = ComponentName(this, "be.fitlog.app.MainActivity")
    private val lightIcon get() = ComponentName(this, "be.fitlog.app.MainActivityLight")

    private fun onIconCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "current" -> result.success(if (isOn(lightIcon, byDefault = false)) "light" else "dark")
            "use" -> {
                val light = call.argument<String>("icon") == "light"
                val on = if (light) lightIcon else darkIcon
                val off = if (light) darkIcon else lightIcon
                result.success(null)
                // Switching the old entry off closes the window that was
                // opened through it - this one - so the app has to open
                // again through the new one. Not while this window is still
                // there: Android would hand the start to it, and then close
                // both. So this window closes first, and the app reopens
                // when it is gone (onDestroy). The old entry goes off only
                // after that, so there is never a moment without a way in.
                main.post {
                    turn(on, on = true)
                    switching = on to off
                    finishAndRemoveTask()
                }
            }
            else -> result.notImplemented()
        }
    }

    /** Whether [component] is on, falling back to what the manifest says. */
    private fun isOn(component: ComponentName, byDefault: Boolean): Boolean =
        when (packageManager.getComponentEnabledSetting(component)) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> byDefault
            else -> false
        }

    private fun turn(component: ComponentName, on: Boolean) =
        packageManager.setComponentEnabledSetting(
            component,
            if (on) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            },
            // Switching the icon is not a reason to close the app you are
            // switching it in.
            PackageManager.DONT_KILL_APP,
        )

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
